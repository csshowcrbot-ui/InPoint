/**
 * API & Real-time Communication Layer
 * 100% Server Single Source of Truth (SSOT)
 * Token-based RBAC Authorization & Multi-tier Plan Enforcement
 */

class ApiService {
    constructor() {
        this.apiBase = this.detectApiBase();
        this.channel = typeof BroadcastChannel !== 'undefined' ? new BroadcastChannel('sc_checkin_realtime') : null;
        this.listeners = {
            checkInChanged: [],
            statsUpdated: [],
            guestAdded: [],
            guestDeleted: [],
            guestAnnounced: [],
            eventChanged: [],
            eventDeleted: [],
            dataSynced: [],
            authChanged: []
        };
        this.token = this.loadToken();
        this.currentUser = this.loadUser();
        this.initRealtimeBus();
        this._lastGuestsHash = '';
        this._lastEventsHash = '';
        this._syncInterval = null;
    }

    loadToken() {
        try {
            return sessionStorage.getItem('inpoint_token') || localStorage.getItem('inpoint_token') || '';
        } catch (e) {
            return '';
        }
    }

    loadUser() {
        try {
            const raw = sessionStorage.getItem('inpoint_user') || localStorage.getItem('inpoint_user');
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    }

    saveSession(token, user, remember = true) {
        this.token = token;
        this.currentUser = user;
        try {
            if (remember) {
                localStorage.setItem('inpoint_token', token);
                localStorage.setItem('inpoint_user', JSON.stringify(user));
            }
            sessionStorage.setItem('inpoint_token', token);
            sessionStorage.setItem('inpoint_user', JSON.stringify(user));
        } catch (e) {}
        this.dispatchLocalEvent('authChanged', { token, user });
    }

    clearSession() {
        this.token = '';
        this.currentUser = null;
        try {
            localStorage.removeItem('inpoint_token');
            localStorage.removeItem('inpoint_user');
            sessionStorage.removeItem('inpoint_token');
            sessionStorage.removeItem('inpoint_user');
        } catch (e) {}
        this.dispatchLocalEvent('authChanged', { token: '', user: null });
    }

    getAuthHeaders(customHeaders = {}) {
        const headers = {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            ...customHeaders
        };
        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
            headers['X-Auth-Token'] = this.token;
        }
        return headers;
    }

    detectApiBase() {
        let path = window.location.pathname;
        path = path.replace(/\/wwwroot(\/.*)?$/i, '').replace(/\/index\.html?$/i, '');
        if (!path.endsWith('/')) {
            path += '/';
        }
        return path;
    }

    initRealtimeBus() {
        if (this.channel) {
            this.channel.onmessage = (event) => {
                const { type, data } = event.data || {};
                this.dispatchLocalEvent(type, data);
            };
        }

        window.addEventListener('storage', (e) => {
            if (e.key === 'sc_last_event' && e.newValue) {
                try {
                    const parsed = JSON.parse(e.newValue);
                    this.dispatchLocalEvent(parsed.type, parsed.data);
                } catch (err) {
                    console.error('Storage sync error', err);
                }
            }
        });
    }

    broadcast(type, data) {
        try {
            if (this.channel) {
                this.channel.postMessage({ type, data, timestamp: Date.now() });
            }
        } catch (e) {}
        try {
            localStorage.setItem('sc_last_event', JSON.stringify({ type, data, timestamp: Date.now() }));
        } catch (e) {}
    }

    on(eventName, callback) {
        if (this.listeners[eventName]) {
            this.listeners[eventName].push(callback);
        }
    }

    dispatchLocalEvent(type, data) {
        if (this.listeners[type]) {
            this.listeners[type].forEach(cb => {
                try { cb(data); } catch (e) { console.error('Listener callback error', e); }
            });
        }
    }

    startCrossDeviceSync(getEventIdFn) {
        if (this._syncInterval) clearInterval(this._syncInterval);
        this._syncInterval = setInterval(async () => {
            const eventId = getEventIdFn();
            if (!eventId) return;
            try {
                // 1. Sync guests for current active event (1s polling)
                const guestsRes = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/guests?_t=${Date.now()}`, {
                    cache: 'no-store',
                    headers: this.getAuthHeaders()
                });
                if (guestsRes.ok) {
                    const list = await guestsRes.json();
                    const newHash = JSON.stringify(list.map(g => [g.guestId || g.GuestId, g.isCheckedIn || g.IsCheckedIn, g.name || g.Name, g.tableNo || g.TableNo, g.rankWeight || g.RankWeight]));
                    if (this._lastGuestsHash && this._lastGuestsHash !== newHash) {
                        this.dispatchLocalEvent('dataSynced', { eventId, guests: list });
                    }
                    this._lastGuestsHash = newHash;
                }

                // 2. Sync events list
                const eventsRes = await fetch(`${this.apiBase}api/events?_t=${Date.now()}`, {
                    cache: 'no-store',
                    headers: this.getAuthHeaders()
                });
                if (eventsRes.ok) {
                    const eventsList = await eventsRes.json();
                    const newEventsHash = JSON.stringify(eventsList.map(e => [e.eventId || e.EventId, e.eventName || e.EventName, e.isActive ?? e.IsActive]));
                    if (this._lastEventsHash && this._lastEventsHash !== newEventsHash) {
                        this.dispatchLocalEvent('eventChanged', { events: eventsList });
                    }
                    this._lastEventsHash = newEventsHash;
                }
            } catch (e) {}
        }, 1000);
    }

    // --- Authentication APIs ---

    async login(username, password, role = 'Member') {
        const res = await fetch(`${this.apiBase}api/auth/login`, {
            method: 'POST',
            cache: 'no-store',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password, role })
        });

        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.success) {
            throw new Error(data.message || (res.status === 401 ? '帳號或密碼錯誤！' : '登入失敗，請確認伺服器連線'));
        }

        this.saveSession(data.token, data, true);
        return data;
    }

    async getMe() {
        if (!this.token) return null;
        try {
            const res = await fetch(`${this.apiBase}api/auth/me?_t=${Date.now()}`, {
                cache: 'no-store',
                headers: this.getAuthHeaders()
            });
            if (res.ok) {
                const user = await res.json();
                this.currentUser = user;
                return user;
            }
            if (res.status === 401) {
                this.clearSession();
            }
            return null;
        } catch (e) {
            return this.currentUser;
        }
    }

    async logout() {
        try {
            await fetch(`${this.apiBase}api/auth/logout`, {
                method: 'POST',
                cache: 'no-store',
                headers: this.getAuthHeaders()
            });
        } catch (e) {}
        this.clearSession();
    }

    // --- Member Management APIs (Admin Only) ---

    async getMembers() {
        const res = await fetch(`${this.apiBase}api/members?_t=${Date.now()}`, {
            cache: 'no-store',
            headers: this.getAuthHeaders()
        });
        if (!res.ok) {
            const errData = await res.json().catch(() => ({}));
            throw new Error(errData.message || (res.status === 401 ? '授權逾期或管理者權限不足，請重新登入' : '無法取得會員清單'));
        }
        return await res.json();
    }

    async createMember(memberData) {
        const res = await fetch(`${this.apiBase}api/members`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify(memberData)
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '建立會員失敗');
        }
        return data;
    }

    async updateMember(userId, memberData) {
        const res = await fetch(`${this.apiBase}api/members/${encodeURIComponent(userId)}`, {
            method: 'PUT',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify(memberData)
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '更新會員失敗');
        }
        return data;
    }

    async toggleMemberStatus(userId) {
        const res = await fetch(`${this.apiBase}api/members/${encodeURIComponent(userId)}/toggle-status`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders()
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '變更會員狀態失敗');
        }
        return data;
    }

    async resetMemberPassword(userId, newPassword) {
        const res = await fetch(`${this.apiBase}api/members/${encodeURIComponent(userId)}/reset-password`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify({ newPassword })
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '重設密碼失敗');
        }
        return data;
    }

    async deleteMember(userId) {
        const res = await fetch(`${this.apiBase}api/members/${encodeURIComponent(userId)}`, {
            method: 'DELETE',
            cache: 'no-store',
            headers: this.getAuthHeaders()
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '刪除會員失敗');
        }
        return data;
    }

    async getMemberEvents(userId) {
        const res = await fetch(`${this.apiBase}api/members/${encodeURIComponent(userId)}/events?_t=${Date.now()}`, {
            cache: 'no-store',
            headers: this.getAuthHeaders()
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '無法取得該會員活動清單');
        }
        return data;
    }

    // --- Events APIs ---

    async getEvents() {
        try {
            const res = await fetch(`${this.apiBase}api/events?_t=${Date.now()}`, {
                cache: 'no-store',
                headers: this.getAuthHeaders()
            });
            if (res.ok) {
                const list = await res.json();
                this._lastEventsHash = JSON.stringify(list.map(e => [e.eventId, e.eventName, e.isActive]));
                return list;
            }
            if (res.status === 401) {
                this.clearSession();
                throw new Error('AUTH_REQUIRED');
            }
            return [];
        } catch (err) {
            if (err.message === 'AUTH_REQUIRED') throw err;
            console.warn('API fetch events failed:', err);
            return [];
        }
    }

    async getGuests(eventId) {
        try {
            const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/guests?_t=${Date.now()}`, {
                cache: 'no-store',
                headers: this.getAuthHeaders()
            });
            if (!res.ok) {
                if (res.status === 401) throw new Error('AUTH_REQUIRED');
                throw new Error('無法取得貴賓名單');
            }
            const list = await res.json();
            this._lastGuestsHash = JSON.stringify(list.map(g => [g.guestId, g.isCheckedIn, g.name, g.tableNo, g.rankWeight]));
            return list;
        } catch (err) {
            console.warn('API fetch guests failed:', err);
            throw err;
        }
    }

    async getStats(eventId) {
        try {
            const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/stats?_t=${Date.now()}`, {
                cache: 'no-store',
                headers: this.getAuthHeaders()
            });
            if (!res.ok) throw new Error('無法取得統計數據');
            return await res.json();
        } catch (err) {
            console.warn('API fetch stats failed:', err);
            return null;
        }
    }

    async toggleCheckIn(eventId, guestId, targetStatus, staffName) {
        try {
            let res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/guests/${encodeURIComponent(guestId)}/checkin`, {
                method: 'POST',
                cache: 'no-store',
                headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
                body: JSON.stringify({ isCheckedIn: targetStatus, staffName: staffName || '現場報到櫃檯' })
            });

            if (!res.ok) {
                res = await fetch(`${this.apiBase}api/events/toggle-checkin`, {
                    method: 'POST',
                    cache: 'no-store',
                    headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
                    body: JSON.stringify({ 
                        eventId: eventId, 
                        guestId: guestId, 
                        isCheckedIn: targetStatus, 
                        staffName: staffName || '現場報到櫃檯' 
                    })
                });
            }

            if (!res.ok) {
                const errorText = await res.text().catch(() => '');
                throw new Error(`伺服器回應錯誤 (${res.status})：${errorText.slice(0, 100)}`);
            }

            const updatedGuest = await res.json();
            this.broadcast('checkInChanged', { eventId, guest: updatedGuest, staffName });
            return updatedGuest;
        } catch (err) {
            console.error('toggleCheckIn error:', err);
            throw err;
        }
    }

    async addGuest(eventId, guestData) {
        const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/guests`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify(guestData)
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '新增貴賓失敗');
        }
        this.broadcast('guestAdded', { eventId, guest: data });
        return data;
    }

    async batchAddGuests(eventId, guestsList) {
        const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/guests/batch`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify(guestsList)
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || '批次匯入失敗');
        }
        this.broadcast('guestAdded', { eventId, count: data.count });
        return data;
    }

    async deleteGuest(eventId, guestId) {
        const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/guests/${encodeURIComponent(guestId)}`, {
            method: 'DELETE',
            cache: 'no-store',
            headers: this.getAuthHeaders()
        });
        if (!res.ok) {
            throw new Error('刪除貴賓失敗');
        }
        this.broadcast('guestDeleted', { eventId, guestId });
        return true;
    }

    async createEvent(eventData) {
        const res = await fetch(`${this.apiBase}api/events`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify(eventData)
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || data.error || (res.status === 401 ? '授權逾期或權限不足，請重新登入' : `建立新活動失敗 (HTTP ${res.status})`));
        }
        this.broadcast('eventChanged', { event: data });
        return data;
    }

    async cloneEvent(sourceEventId, cloneData) {
        const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(sourceEventId)}/clone`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify(cloneData)
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || data.error || (res.status === 401 ? '授權逾期或權限不足，請重新登入' : `複製活動範本失敗 (HTTP ${res.status})`));
        }
        this.broadcast('eventChanged', { event: data.clonedEvent });
        return data.clonedEvent;
    }

    async deleteEvent(eventId) {
        const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}`, {
            method: 'DELETE',
            cache: 'no-store',
            headers: this.getAuthHeaders()
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || data.error || (res.status === 401 ? '授權逾期或權限不足，請重新登入' : `刪除活動失敗 (HTTP ${res.status})`));
        }
        this.broadcast('eventDeleted', { eventId });
        return true;
    }

    async toggleEventActive(eventId, isActive) {
        const res = await fetch(`${this.apiBase}api/events/${encodeURIComponent(eventId)}/toggle-active`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify({ eventId, isActive })
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
            throw new Error(data.message || data.error || (res.status === 401 ? '授權逾期或權限不足，請重新登入' : `變更活動狀態失敗 (HTTP ${res.status})`));
        }
        this.broadcast('eventChanged', { eventId, isActive: data.isActive });
        return data;
    }

    async parseAiGuests(eventId, rawText) {
        const res = await fetch(`${this.apiBase}api/ai/parse-guests`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify({ eventId, rawText })
        });
        if (!res.ok) throw new Error('AI 解析失敗');
        return await res.json();
    }

    async queryAiAssistant(eventId, query) {
        const res = await fetch(`${this.apiBase}api/ai/query-status`, {
            method: 'POST',
            cache: 'no-store',
            headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
            body: JSON.stringify({ eventId, query })
        });
        if (!res.ok) throw new Error('AI 助理查詢失敗');
        return await res.json();
    }

    getExportUrl(eventId) {
        const tokenParam = this.token ? `?token=${encodeURIComponent(this.token)}` : '';
        return `${this.apiBase}api/events/${encodeURIComponent(eventId)}/export${tokenParam}`;
    }
}

window.apiService = new ApiService();
