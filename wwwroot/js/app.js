/**
 * 智慧活動報到系統 (InPoint Check-in & Host Dashboard)
 * Master Application Controller with Full RBAC, Privacy Guard, & Plan Management
 */

class CheckInApp {
    constructor() {
        this.currentEventId = '';
        this.events = [];
        this.guests = [];
        this.members = [];
        this.stats = {
            totalGuests: 0,
            checkedInCount: 0,
            pendingCount: 0,
            attendanceRate: 0,
            vipTotal: 0,
            vipCheckedIn: 0,
            vipAttendanceRate: 0,
            maxGuestsAllowed: 500
        };

        // Filter and view states
        this.currentTab = 'staff'; // staff, host, admin, ai, members
        this.searchQuery = '';
        this.activeFilter = 'all'; // all, pending, checked, vip
        this.loginRole = 'Member'; // Member or Admin

        // Scanner & Modals
        this.videoStream = null;
        this.isScanning = false;
        this.pendingDeleteGuestId = null;
        this.pendingDeleteEventId = null;
        this.pendingToggleActiveEventId = null;
        this.parsedExcelRows = [];

        // VIP Host Announcements
        this.announcedGuests = new Set();

        // 姓名遮蔽控制 (預設開啟遮蔽防護，支援隨時開關 toggle)
        const savedMask = localStorage.getItem('inpoint_name_masked');
        this.isNameMasked = savedMask !== null ? savedMask === 'true' : true;

        this.init();
    }

    async init() {
        this.bindEvents();
        this.initRealtimeListeners();

        // 1. Check Authentication state
        const user = await window.apiService.getMe();
        if (user) {
            this.hideLoginOverlay();
            this.renderUserHeader(user);
            await this.loadEvents();
            if (this.currentEventId) {
                await this.loadGuestsAndStats();
            } else {
                this.resetStats();
                this.renderAllViews();
            }
            if (user.role === 'Admin') {
                await this.loadMembers();
            }
            if (window.apiService.startCrossDeviceSync) {
                window.apiService.startCrossDeviceSync(() => this.currentEventId);
            }
        } else {
            this.resetStats();
            this.renderAllViews();
            this.showLoginOverlay();
        }
    }

    bindEvents() {
        // Tab Navigation
        document.querySelectorAll('.nav-tab-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const tab = btn.dataset.tab;
                this.switchTab(tab);
            });
        });

        // Event Selector
        const eventSelect = document.getElementById('eventSelect');
        if (eventSelect) {
            eventSelect.addEventListener('change', async (e) => {
                this.currentEventId = e.target.value;
                await this.loadGuestsAndStats();
            });
        }

        // Search Input
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchQuery = e.target.value.trim().toLowerCase();
                this.renderStaffGuests();
            });

            searchInput.addEventListener('keydown', async (e) => {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    await this.handleSearchCheckIn();
                }
            });
        }

        // Filter Chips (Staff view)
        document.querySelectorAll('.filter-chip').forEach(chip => {
            chip.addEventListener('click', () => {
                document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
                chip.classList.add('active');
                this.activeFilter = chip.dataset.filter;
                this.renderStaffGuests();
            });
        });

        // Sound Toggle Button
        const soundToggleBtn = document.getElementById('soundToggleBtn');
        if (soundToggleBtn) {
            soundToggleBtn.addEventListener('click', () => {
                const enabled = window.soundManager ? window.soundManager.toggle() : true;
                soundToggleBtn.innerHTML = enabled ? '🔊' : '🔇';
                soundToggleBtn.title = enabled ? '音效已開啟' : '音效已靜音';
            });
        }

        // Add Guest Form Submit
        const addGuestForm = document.getElementById('addGuestForm');
        if (addGuestForm) {
            addGuestForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.handleAddNewGuest();
            });
        }

        // Confirm Delete Button in Modal (Guest)
        const confirmDeleteGuestBtn = document.getElementById('confirmDeleteGuestBtn');
        if (confirmDeleteGuestBtn) {
            confirmDeleteGuestBtn.addEventListener('click', async () => {
                await this.executeDeleteGuest();
            });
        }

        // Confirm Delete Event Button in Modal (Event)
        const confirmDeleteEventBtn = document.getElementById('confirmDeleteEventBtn');
        if (confirmDeleteEventBtn) {
            confirmDeleteEventBtn.addEventListener('click', async () => {
                await this.executeDeleteEvent();
            });
        }

        // Confirm Toggle Event Active Button
        const confirmToggleEventActiveBtn = document.getElementById('confirmToggleEventActiveBtn');
        if (confirmToggleEventActiveBtn) {
            confirmToggleEventActiveBtn.addEventListener('click', async () => {
                await this.executeToggleEventActive();
            });
        }

        // Confirm Delete Member Event Button
        const confirmDeleteMemberEventBtn = document.getElementById('confirmDeleteMemberEventBtn');
        if (confirmDeleteMemberEventBtn) {
            confirmDeleteMemberEventBtn.addEventListener('click', async () => {
                await this.executeDeleteMemberEvent();
            });
        }
    }

    initRealtimeListeners() {
        window.apiService.on('checkInChanged', (data) => {
            if (data.eventId === this.currentEventId && data.guest) {
                const index = this.guests.findIndex(g => g.guestId === data.guest.guestId);
                if (index !== -1) {
                    this.guests[index] = data.guest;
                } else {
                    this.guests.push(data.guest);
                }

                if (data.guest.isCheckedIn) {
                    if (data.guest.rankWeight <= 2) {
                        if (window.soundManager) window.soundManager.playVipFanfare();
                        this.showVipArrivalToast(data.guest);
                    } else {
                        if (window.soundManager) window.soundManager.playCheckInSuccess();
                    }
                } else {
                    if (window.soundManager) window.soundManager.playUndoSound();
                }

                this.updateStatsLocally();
                this.renderAllViews();
            }
        });

        window.apiService.on('guestAdded', async (data) => {
            if (data.eventId === this.currentEventId) {
                await this.loadGuestsAndStats();
            }
        });

        window.apiService.on('guestDeleted', (data) => {
            if (data.eventId === this.currentEventId) {
                this.guests = this.guests.filter(g => g.guestId !== data.guestId);
                this.updateStatsLocally();
                this.renderAllViews();
            }
        });

        window.apiService.on('eventChanged', async () => {
            await this.loadEvents();
        });

        window.apiService.on('eventDeleted', async (data) => {
            this.events = this.events.filter(e => e.eventId !== data.eventId);
            if (this.currentEventId === data.eventId || !this.events.some(e => e.eventId === this.currentEventId)) {
                this.currentEventId = this.events.length > 0 ? this.events[0].eventId : '';
                if (this.currentEventId) {
                    await this.loadGuestsAndStats();
                } else {
                    this.resetStats();
                    this.renderAllViews();
                }
            }
            this.populateEventSelector();
        });

        window.apiService.on('dataSynced', (data) => {
            if (data.eventId === this.currentEventId && data.guests) {
                const newlyCheckedIn = data.guests.filter(g => {
                    const gId = g.guestId || g.GuestId;
                    const old = this.guests.find(og => (og.guestId || og.GuestId) === gId);
                    const isNewChecked = g.isCheckedIn || g.IsCheckedIn;
                    const wasOldChecked = old ? (old.isCheckedIn || old.IsCheckedIn) : false;
                    return isNewChecked && !wasOldChecked;
                });

                this.guests = data.guests;
                this.updateStatsLocally();
                this.renderAllViews();

                if (newlyCheckedIn.length > 0) {
                    newlyCheckedIn.forEach(guest => {
                        const name = guest.name || guest.Name;
                        const rank = guest.rankWeight || guest.RankWeight || 4;
                        if (rank <= 2) {
                            if (window.soundManager) window.soundManager.playVipFanfare();
                            this.showVipArrivalToast(guest);
                        } else {
                            if (window.soundManager) window.soundManager.playCheckInSuccess();
                        }
                        this.showToast(`📱 手機掃碼自主報到：【${name}】已完成簽到！`, 'success');
                    });
                }
            }
        });
    }

    // =========================================================================
    // AUTHENTICATION & PRIVACY GUARD (Requirement 1 & 2)
    // =========================================================================

    showLoginOverlay() {
        const overlay = document.getElementById('loginOverlay');
        if (overlay) overlay.classList.remove('hidden');
        const userInp = document.getElementById('loginUsername');
        const passInp = document.getElementById('loginPassword');
        if (userInp) userInp.value = '';
        if (passInp) passInp.value = '';
        const alertBox = document.getElementById('loginAlertBox');
        if (alertBox) alertBox.style.display = 'none';
    }

    hideLoginOverlay() {
        const overlay = document.getElementById('loginOverlay');
        if (overlay) overlay.classList.add('hidden');
    }

    switchLoginTab(role) {
        this.loginRole = role;
        const tabMem = document.getElementById('loginTabMember');
        const tabAdm = document.getElementById('loginTabAdmin');
        const userLabel = document.getElementById('loginUsernameLabel');
        const userInp = document.getElementById('loginUsername');
        const alertBox = document.getElementById('loginAlertBox');
        if (alertBox) alertBox.style.display = 'none';

        if (role === 'Admin') {
            if (tabMem) tabMem.classList.remove('active');
            if (tabAdm) tabAdm.classList.add('active');
            if (userLabel) userLabel.innerText = '管理帳號';
            if (userInp) userInp.placeholder = '請輸入管理帳號';
        } else {
            if (tabAdm) tabAdm.classList.remove('active');
            if (tabMem) tabMem.classList.add('active');
            if (userLabel) userLabel.innerText = '會員帳號';
            if (userInp) userInp.placeholder = '請輸入會員帳號';
        }
    }

    async handleLoginSubmit(e) {
        if (e) e.preventDefault();
        const username = document.getElementById('loginUsername')?.value.trim() || '';
        const password = document.getElementById('loginPassword')?.value.trim() || '';
        const alertBox = document.getElementById('loginAlertBox');
        const submitBtn = document.getElementById('loginSubmitBtn');

        if (!username || !password) {
            if (alertBox) {
                alertBox.className = 'login-alert danger';
                alertBox.innerText = '請輸入帳號與密碼！';
                alertBox.style.display = 'block';
            }
            return;
        }

        try {
            if (submitBtn) {
                submitBtn.disabled = true;
                submitBtn.innerText = '驗證登入中...';
            }

            const res = await window.apiService.login(username, password, this.loginRole);
            if (res.success) {
                this.hideLoginOverlay();
                this.renderUserHeader(res);
                this.showToast(res.message || '🎉 登入成功！', 'success');
                this.resetStats();
                this.currentEventId = '';
                await this.loadEvents();
                if (this.currentEventId) {
                    await this.loadGuestsAndStats();
                } else {
                    this.resetStats();
                    this.renderAllViews();
                }
                if (res.role === 'Admin') {
                    await this.loadMembers();
                }
            }
        } catch (err) {
            if (alertBox) {
                alertBox.className = 'login-alert danger';
                alertBox.innerText = err.message || '登入失敗，請確認帳號與密碼！';
                alertBox.style.display = 'block';
            }
        } finally {
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.innerText = '🚀 安全驗證登入';
            }
        }
    }

    handleLogout() {
        if (confirm('確定要登出系統嗎？')) {
            window.apiService.logout();
            const widget = document.getElementById('headerUserWidget');
            if (widget) widget.style.display = 'none';
            const navMembers = document.getElementById('navTabMembers');
            if (navMembers) navMembers.style.display = 'none';
            const navAi = document.getElementById('navTabAi');
            if (navAi) navAi.style.display = '';
            this.events = [];
            this.currentEventId = '';
            this.resetStats();
            this.populateEventSelector();
            this.renderAllViews();
            this.showLoginOverlay();
            this.showToast('您已安全登出', 'info');
        }
    }

    renderUserHeader(user) {
        const widget = document.getElementById('headerUserWidget');
        const nameText = document.getElementById('userDisplayNameText');
        const avatarLetter = document.getElementById('userAvatarLetter');
        const planBadge = document.getElementById('userPlanBadge');
        const remainingDaysText = document.getElementById('userRemainingDaysText');
        const navMembers = document.getElementById('navTabMembers');
        const navAi = document.getElementById('navTabAi');

        if (!user || !widget) return;
        widget.style.display = 'flex';

        const dispName = user.displayName || user.username || '使用者';
        if (nameText) nameText.innerText = `${dispName} (${user.organization || '貴賓單位'})`;
        if (avatarLetter) avatarLetter.innerText = dispName.charAt(0).toUpperCase();

        if (user.role === 'Admin') {
            if (planBadge) {
                planBadge.className = 'plan-badge-admin';
                planBadge.innerText = '🛡️ 最高管理者 (無限制)';
            }
            if (remainingDaysText) remainingDaysText.innerText = '';
            if (navMembers) navMembers.style.display = 'flex';
            if (navAi) navAi.style.display = 'none';
            if (this.currentTab === 'ai') {
                this.switchTab('staff');
            }
        } else {
            if (navMembers) navMembers.style.display = 'none';
            if (navAi) navAi.style.display = '';
            if (this.currentTab === 'members') {
                this.switchTab('staff');
            }
            if (user.planType === 'AnnualOrg') {
                if (planBadge) {
                    planBadge.className = 'plan-badge-annual';
                    planBadge.innerText = '👑 機構年度 (1500人/多場次)';
                }
            } else {
                if (planBadge) {
                    planBadge.className = 'plan-badge-single';
                    planBadge.innerText = '🌟 單場活動 (500人/7天)';
                }
            }

            if (remainingDaysText) {
                if (user.isExpired) {
                    remainingDaysText.innerHTML = '<strong style="color: #DC2626;">(已過期)</strong>';
                } else {
                    remainingDaysText.innerText = `剩餘 ${user.remainingDays || 0} 天`;
                }
            }
        }
    }

    // =========================================================================
    // MEMBER MANAGEMENT (Requirement 3: Admin Only)
    // =========================================================================

    async loadMembers() {
        const tbody = document.getElementById('memberTableBody');
        try {
            const data = await window.apiService.getMembers();
            this.members = Array.isArray(data) ? data : [];
            this.renderMembersTable(this.members);
            this.updateMemberStats();
        } catch (err) {
            console.warn('Load members error:', err);
            if (tbody && (!this.members || this.members.length === 0)) {
                tbody.innerHTML = `
                  <tr>
                    <td colspan="7" style="text-align: center; padding: 28px; color: var(--text-muted);">
                      <div>⚠️ 無法取得會員名單 (${this.escapeHtml(err.message || '連線逾時或權限不足')})</div>
                      <button type="button" class="btn btn-secondary" style="margin-top: 10px; font-size: 12px; padding: 6px 14px;" onclick="app.loadMembers()">
                        🔄 點擊重新載入
                      </button>
                    </td>
                  </tr>
                `;
            }
        }
    }

    updateMemberStats() {
        const totalBox = document.getElementById('memberStatTotal');
        const singleBox = document.getElementById('memberStatSingle');
        const annualBox = document.getElementById('memberStatAnnual');
        const expiringBox = document.getElementById('memberStatExpiring');

        const total = this.members.length;
        const single = this.members.filter(m => m.planType === 'SingleEvent').length;
        const annual = this.members.filter(m => m.planType === 'AnnualOrg').length;
        const expiring = this.members.filter(m => m.isExpired || m.remainingDays <= 3).length;

        if (totalBox) totalBox.innerText = total;
        if (singleBox) singleBox.innerText = single;
        if (annualBox) annualBox.innerText = annual;
        if (expiringBox) expiringBox.innerText = expiring;
    }

    renderMembersTable(members) {
        const tbody = document.getElementById('memberTableBody');
        if (!tbody) return;

        if (!members || members.length === 0) {
            tbody.innerHTML = `
              <tr>
                <td colspan="7" style="text-align: center; padding: 32px; color: var(--text-muted);">
                  📭 目前尚無一般會員帳號，點擊上方「➕ 建立新一般會員」開始指派。
                </td>
              </tr>
            `;
            return;
        }

        tbody.innerHTML = members.map(m => {
            const isSingle = m.planType === 'SingleEvent';
            const planBadge = isSingle
                ? `<span class="plan-badge-single" title="單一場次授權、7天有效、上限500人">🌟 單場活動 (500人/7天)</span>`
                : `<span class="plan-badge-annual" title="無限場次、1500人上限、範本複製">👑 機構年度 (1500人/無限場次/範本複製)</span>`;

            let expireDateStr = '永久有效';
            let isExpired = false;
            let remDays = 9999;
            if (m.expireAt) {
                try {
                    const d = new Date(m.expireAt);
                    if (!isNaN(d.getTime())) {
                        expireDateStr = d.toISOString().split('T')[0];
                        isExpired = d.getTime() < Date.now();
                        remDays = Math.max(0, Math.ceil((d.getTime() - Date.now()) / (1000 * 60 * 60 * 24)));
                    } else {
                        expireDateStr = String(m.expireAt).substring(0, 10);
                    }
                } catch (e) {
                    expireDateStr = String(m.expireAt).substring(0, 10);
                }
            }
            if (typeof m.isExpired === 'boolean') isExpired = m.isExpired;
            if (typeof m.remainingDays === 'number') remDays = m.remainingDays;

            const expiryTag = isExpired
                ? `<span style="color: #DC2626; font-weight: 700;">⚠️ 已過期 (${expireDateStr})</span>`
                : (remDays <= 3
                    ? `<span style="color: #D97706; font-weight: 700;">⏳ 剩餘 ${remDays} 天 (${expireDateStr})</span>`
                    : `<span>剩餘 ${remDays} 天 (${expireDateStr})</span>`);

            const statusBadge = m.isActive
                ? `<span style="display: inline-block; padding: 2px 8px; border-radius: 9999px; background: #DEF7EC; color: #03543F; font-weight: 700; font-size: 11px;">🟢 啟用中</span>`
                : `<span style="display: inline-block; padding: 2px 8px; border-radius: 9999px; background: #FDE8E8; color: #9B1C1C; font-weight: 700; font-size: 11px;">🔴 已停用</span>`;

            const eventCount = m.eventCount || 0;
            const eventQuotaStr = isSingle ? `${eventCount} / 1 場` : `${eventCount} 場 (無上限)`;

            let createdAtStr = '';
            if (m.createdAt) {
                try {
                    const cd = new Date(m.createdAt);
                    if (!isNaN(cd.getTime())) createdAtStr = cd.toLocaleDateString();
                } catch (e) {}
            }

            return `
              <tr>
                <td>
                  <strong style="color: var(--primary-forest); font-size: 14px;">${this.escapeHtml(m.username || '')}</strong>
                  ${createdAtStr ? `<div style="font-size: 11px; color: var(--text-muted);">建立於 ${createdAtStr}</div>` : ''}
                </td>
                <td>
                  <div style="font-weight: 700; color: var(--text-charcoal);">${this.escapeHtml(m.organization || '無單位')}</div>
                  <div style="font-size: 12px; color: var(--text-muted);">${this.escapeHtml(m.displayName || '')}</div>
                </td>
                <td>
                  ${planBadge}
                  <div style="font-size: 11px; color: var(--text-muted); margin-top: 3px;">單場上限：${m.maxGuestsPerEvent || 500} 人</div>
                </td>
                <td>${expiryTag}</td>
                <td>
                  <button class="member-event-count-badge" onclick="app.openMemberEventsModal('${m.userId}', '${this.escapeHtml(m.username)}', '${this.escapeHtml(m.displayName || m.organization)}')" title="點擊檢視與管理此會員名下所有活動">
                    <span>📂 ${eventQuotaStr}</span>
                  </button>
                </td>
                <td style="text-align: center;">${statusBadge}</td>
                <td style="text-align: center;">
                  <div style="display: flex; gap: 6px; justify-content: center; align-items: center; flex-wrap: wrap;">
                    <button class="btn btn-secondary" style="font-size: 11px; padding: 4px 8px; color: var(--primary-forest); font-weight: 700;" onclick="app.openMemberEventsModal('${m.userId}', '${this.escapeHtml(m.username)}', '${this.escapeHtml(m.displayName || m.organization)}')" title="活動管理：停用/封存、刪除、複製為新範本">📂 活動管理</button>
                    <button class="btn btn-secondary" style="font-size: 11px; padding: 4px 8px;" onclick="app.showEditMemberModal('${m.userId}')" title="編輯方案或延長效期">✏️ 編輯/續約</button>
                    <button class="btn btn-secondary" style="font-size: 11px; padding: 4px 8px;" onclick="app.toggleMemberStatus('${m.userId}')" title="切換啟用/停用">${m.isActive ? '⏸️' : '▶️'}</button>
                    <button class="btn btn-secondary" style="font-size: 11px; padding: 4px 8px; color: var(--alert-red);" onclick="app.deleteMember('${m.userId}', '${this.escapeHtml(m.username)}')" title="刪除會員">🗑️</button>
                  </div>
                </td>
              </tr>
            `;
        }).join('');
    }

    showCreateMemberModal() {
        this.selectPlanOption('SingleEvent');
        const modal = document.getElementById('createMemberModal');
        if (modal) modal.classList.add('active');

        // Set default expiry date (+7 days)
        const d = new Date();
        d.setDate(d.getDate() + 7);
        const expireInput = document.getElementById('createMemberExpireAt');
        if (expireInput) expireInput.value = d.toISOString().split('T')[0];
    }

    closeCreateMemberModal() {
        const modal = document.getElementById('createMemberModal');
        if (modal) modal.classList.remove('active');
        const form = document.getElementById('createMemberForm');
        if (form) form.reset();
    }

    selectPlanOption(planType) {
        const singleCard = document.getElementById('planOptionSingle');
        const annualCard = document.getElementById('planOptionAnnual');
        const planInput = document.getElementById('createMemberPlanType');
        const maxGuestsInput = document.getElementById('createMemberMaxGuests');
        const expireInput = document.getElementById('createMemberExpireAt');

        if (planInput) planInput.value = planType;

        const d = new Date();
        if (planType === 'AnnualOrg') {
            if (singleCard) singleCard.classList.remove('selected');
            if (annualCard) annualCard.classList.add('selected');
            if (maxGuestsInput) maxGuestsInput.value = '1500';
            d.setFullYear(d.getFullYear() + 1);
        } else {
            if (annualCard) annualCard.classList.remove('selected');
            if (singleCard) singleCard.classList.add('selected');
            if (maxGuestsInput) maxGuestsInput.value = '500';
            d.setDate(d.getDate() + 7);
        }

        if (expireInput) expireInput.value = d.toISOString().split('T')[0];
    }

    async handleCreateMemberSubmit(e) {
        if (e) e.preventDefault();
        const username = document.getElementById('createMemberUsername')?.value.trim();
        const password = document.getElementById('createMemberPassword')?.value.trim();
        const org = document.getElementById('createMemberOrg')?.value.trim();
        const displayName = document.getElementById('createMemberDisplayName')?.value.trim();
        const planType = document.getElementById('createMemberPlanType')?.value || 'SingleEvent';
        const expireAt = document.getElementById('createMemberExpireAt')?.value;
        const maxGuests = parseInt(document.getElementById('createMemberMaxGuests')?.value, 10) || 500;
        const notes = document.getElementById('createMemberNotes')?.value.trim();

        if (!username || !password || !org || !expireAt) {
            alert('請填寫必填欄位 (帳號、密碼、機構、有效期限)！');
            return;
        }

        try {
            const res = await window.apiService.createMember({
                username,
                password,
                organization: org,
                displayName: displayName || username,
                planType,
                expireAt: new Date(expireAt).toISOString(),
                maxGuestsPerEvent: maxGuests,
                notes
            });

            this.showToast(`🎉 會員【${username}】建立成功！`, 'success');
            this.closeCreateMemberModal();
            await this.loadMembers();
        } catch (err) {
            alert(err.message || '建立會員失敗');
        }
    }

    showEditMemberModal(userId) {
        const member = this.members.find(m => m.userId === userId);
        if (!member) return;

        document.getElementById('editMemberUserId').value = member.userId;
        document.getElementById('editMemberUsername').value = member.username;
        document.getElementById('editMemberOrg').value = member.organization || '';
        document.getElementById('editMemberDisplayName').value = member.displayName || '';
        document.getElementById('editMemberPlanType').value = member.planType;
        document.getElementById('editMemberMaxGuests').value = member.maxGuestsPerEvent;
        document.getElementById('editMemberIsActive').value = member.isActive ? 'true' : 'false';
        document.getElementById('editMemberNotes').value = member.notes || '';
        document.getElementById('editMemberPassword').value = '';

        if (member.expireAt) {
            document.getElementById('editMemberExpireAt').value = new Date(member.expireAt).toISOString().split('T')[0];
        }

        const modal = document.getElementById('editMemberModal');
        if (modal) modal.classList.add('active');
    }

    closeEditMemberModal() {
        const modal = document.getElementById('editMemberModal');
        if (modal) modal.classList.remove('active');
    }

    handleEditPlanTypeChange() {
        const plan = document.getElementById('editMemberPlanType').value;
        const maxGuestsInput = document.getElementById('editMemberMaxGuests');
        if (plan === 'AnnualOrg') {
            maxGuestsInput.value = '1500';
        } else {
            maxGuestsInput.value = '500';
        }
    }

    async handleEditMemberSubmit(e) {
        if (e) e.preventDefault();
        const userId = document.getElementById('editMemberUserId').value;
        const org = document.getElementById('editMemberOrg').value.trim();
        const displayName = document.getElementById('editMemberDisplayName').value.trim();
        const planType = document.getElementById('editMemberPlanType').value;
        const expireAt = document.getElementById('editMemberExpireAt').value;
        const maxGuests = parseInt(document.getElementById('editMemberMaxGuests').value, 10) || 500;
        const isActive = document.getElementById('editMemberIsActive').value === 'true';
        const password = document.getElementById('editMemberPassword').value.trim();
        const notes = document.getElementById('editMemberNotes').value.trim();

        try {
            await window.apiService.updateMember(userId, {
                organization: org,
                displayName,
                planType,
                expireAt: expireAt ? new Date(expireAt).toISOString() : null,
                maxGuestsPerEvent: maxGuests,
                isActive,
                password: password || undefined,
                notes
            });

            this.showToast('會員資料與方案更新成功！', 'success');
            this.closeEditMemberModal();
            await this.loadMembers();
        } catch (err) {
            alert(err.message || '更新會員失敗');
        }
    }

    async toggleMemberStatus(userId) {
        try {
            await window.apiService.toggleMemberStatus(userId);
            this.showToast('會員狀態已變更', 'info');
            await this.loadMembers();
        } catch (err) {
            alert(err.message || '變更失敗');
        }
    }

    async deleteMember(userId, username) {
        if (confirm(`確定要刪除會員帳號「${username}」嗎？刪除後該會員將無法再登入。`)) {
            try {
                await window.apiService.deleteMember(userId);
                this.showToast(`會員「${username}」已刪除`, 'success');
                await this.loadMembers();
            } catch (err) {
                alert(err.message || '刪除失敗');
            }
        }
    }

    // =========================================================================
    // MEMBER EVENTS MANAGEMENT (Admin managing activities for specific member)
    // =========================================================================

    async openMemberEventsModal(userId, username, displayName) {
        this.currentManagingMemberUserId = userId;
        this.currentManagingMemberUsername = username;
        this.currentManagingMemberDisplayName = displayName;

        const modal = document.getElementById('memberEventsModal');
        if (modal) modal.classList.add('active');

        const title = document.getElementById('memberEventsModalTitle');
        if (title) title.innerHTML = `<span>📂</span> 會員活動管理：【${this.escapeHtml(username)}】`;

        const subtitle = document.getElementById('memberEventsModalSubtitle');
        if (subtitle) subtitle.innerText = `管理 ${displayName || username} 名下建立的所有活動場次（停用/封存、刪除、複製範本）`;

        await this.loadMemberEvents(userId);
    }

    closeMemberEventsModal() {
        const modal = document.getElementById('memberEventsModal');
        if (modal) modal.classList.remove('active');
        this.currentManagingMemberUserId = null;
        this.currentManagingMemberUsername = null;
        this.currentManagingMemberDisplayName = null;
    }

    async refreshCurrentMemberEvents() {
        if (this.currentManagingMemberUserId) {
            await this.loadMemberEvents(this.currentManagingMemberUserId);
            this.showToast('已重新整理活動清單', 'info');
        }
    }

    async loadMemberEvents(userId) {
        const tbody = document.getElementById('memberEventsTableBody');
        const countText = document.getElementById('memberEventsCountText');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; padding: 24px; color: var(--text-muted);">載入活動清單中...</td></tr>`;
        }

        try {
            const data = await window.apiService.getMemberEvents(userId);
            const user = data.user;
            const events = data.events || [];

            // Update user info banner
            const bannerOrg = document.getElementById('memberEventsBannerOrg');
            const bannerUser = document.getElementById('memberEventsBannerUser');
            const bannerPlan = document.getElementById('memberEventsBannerPlan');
            const bannerExpire = document.getElementById('memberEventsBannerExpire');

            if (bannerOrg) bannerOrg.innerText = user.organization || '無單位';
            if (bannerUser) bannerUser.innerText = `${user.displayName || user.username} (@${user.username})`;
            if (bannerPlan) {
                bannerPlan.innerHTML = user.planType === 'AnnualOrg'
                    ? '<span class="plan-badge-annual" style="font-size: 11px;">👑 機構年度 (1500人/多場次)</span>'
                    : '<span class="plan-badge-single" style="font-size: 11px;">🌟 單場活動 (500人/7天)</span>';
            }
            if (bannerExpire) {
                bannerExpire.innerText = user.expireAt ? new Date(user.expireAt).toLocaleDateString() : '永久有效';
            }

            if (countText) {
                countText.innerText = `共 ${events.length} 場活動` + (user.planType === 'SingleEvent' ? ` (上限 1 場)` : ` (無上限)`);
            }

            this.renderMemberEventsList(user, events);
        } catch (err) {
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; padding: 24px; color: var(--alert-red);">⚠️ 載入失敗：${this.escapeHtml(err.message)}</td></tr>`;
            }
        }
    }

    renderMemberEventsList(user, events) {
        const tbody = document.getElementById('memberEventsTableBody');
        if (!tbody) return;

        if (!events || events.length === 0) {
            tbody.innerHTML = `
              <tr>
                <td colspan="5" style="text-align: center; padding: 36px 16px;">
                  <div style="font-size: 32px; margin-bottom: 8px;">📭</div>
                  <div style="font-weight: 700; color: var(--text-charcoal); font-size: 14px;">此會員目前尚未建立任何活動場次</div>
                  <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">點擊上方「➕ 為此會員建立新活動」可為該會員指派新活動。</div>
                </td>
              </tr>
            `;
            return;
        }

        tbody.innerHTML = events.map(ev => {
            const dateStr = ev.eventDate ? new Date(ev.eventDate).toLocaleString('zh-TW', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' }) : '未排定日期';
            const rate = ev.totalGuests > 0 ? Math.round((ev.checkedInCount / ev.totalGuests) * 100) : 0;
            const isArchived = !ev.isActive;
            const statusBadge = ev.isActive
                ? `<span style="display: inline-block; padding: 3px 9px; border-radius: 9999px; background: #DEF7EC; color: #03543F; font-weight: 700; font-size: 11px;">🟢 進行中</span>`
                : `<span style="display: inline-block; padding: 3px 9px; border-radius: 9999px; background: #F3F4F6; color: #4B5563; font-weight: 700; font-size: 11px;">⏸️ 已封存/停用</span>`;

            return `
              <tr class="${isArchived ? 'event-archived' : ''}">
                <td>
                  <div style="font-weight: 800; color: var(--primary-forest); font-size: 14px;">${this.escapeHtml(ev.eventName)}</div>
                  <div style="font-size: 11px; color: var(--text-muted); font-family: monospace; margin-top: 2px;">ID: ${this.escapeHtml(ev.eventId)}</div>
                  ${ev.description ? `<div style="font-size: 11px; color: #64748B; margin-top: 2px; max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${this.escapeHtml(ev.description)}</div>` : ''}
                </td>
                <td>
                  <div style="font-weight: 700; color: var(--text-charcoal); font-size: 12.5px;">📅 ${dateStr}</div>
                  <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">📍 ${this.escapeHtml(ev.location || '大會國際會議廳')}</div>
                </td>
                <td style="text-align: center;">
                  <div style="font-size: 12.5px; font-weight: 700; color: var(--text-charcoal);">
                    ${ev.checkedInCount} / ${ev.totalGuests} 人
                    <span style="font-size: 11px; color: var(--primary-forest); margin-left: 4px;">(${rate}%)</span>
                  </div>
                  <div class="member-event-progress-wrap">
                    <div class="member-event-progress-bar" style="width: ${rate}%;"></div>
                  </div>
                </td>
                <td style="text-align: center;">${statusBadge}</td>
                <td style="text-align: center;">
                  <div style="display: flex; gap: 5px; justify-content: center; flex-wrap: wrap;">
                    <button class="btn-action-sm ${ev.isActive ? 'btn-secondary' : 'btn-primary'}" onclick="app.toggleMemberEventStatus('${ev.eventId}', ${ev.isActive})" title="${ev.isActive ? '停用/封存此活動' : '重新啟用此活動'}">
                      <span>${ev.isActive ? '⏸️ 封存' : '▶️ 啟用'}</span>
                    </button>
                    <button class="btn-action-sm btn-secondary" style="color: #B45309; border-color: #FDE68A;" onclick="app.showCloneMemberEventModal('${ev.eventId}', '${this.escapeHtml(ev.eventName)}')" title="以此活動為範本複製全新場次">
                      <span>📋 複製範本</span>
                    </button>
                    <button class="btn-action-sm btn-secondary" style="color: var(--alert-red); border-color: #FECACA;" onclick="app.confirmDeleteMemberEvent('${ev.eventId}', '${this.escapeHtml(ev.eventName)}')" title="刪除此活動及其貴賓名冊">
                      <span>🗑️ 刪除</span>
                    </button>
                    <button class="btn-action-sm btn-secondary" style="color: #4F46E5;" onclick="app.jumpToMemberEvent('${ev.eventId}')" title="切換至此活動並開啟報到處">
                      <span>🔗 進入</span>
                    </button>
                  </div>
                </td>
              </tr>
            `;
        }).join('');
    }

    async toggleMemberEventStatus(eventId, currentIsActive) {
        const actionName = currentIsActive ? '封存/停用' : '重新啟用';
        try {
            await window.apiService.toggleEventActive(eventId, !currentIsActive);
            this.showToast(`活動已${actionName}！`, 'success');
            if (this.currentManagingMemberUserId) {
                await this.loadMemberEvents(this.currentManagingMemberUserId);
            }
            await this.loadEvents();
            await this.loadMembers();
        } catch (err) {
            alert(err.message || `${actionName}失敗`);
        }
    }

    showCloneMemberEventModal(eventId, eventName) {
        const modal = document.getElementById('cloneMemberEventModal');
        if (!modal) return;

        document.getElementById('cloneMemberEventSourceId').value = eventId;
        document.getElementById('cloneMemberEventTargetUserId').value = this.currentManagingMemberUserId || '';
        document.getElementById('cloneMemberEventTargetUsername').value = this.currentManagingMemberUsername || '';
        document.getElementById('cloneMemberEventSourceDisplay').value = eventName;
        document.getElementById('cloneMemberEventNewName').value = `[複製] ${eventName}`;

        // Default new date (+7 days)
        const d = new Date();
        d.setDate(d.getDate() + 7);
        const isoStr = new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
        document.getElementById('cloneMemberEventNewDate').value = isoStr;
        document.getElementById('cloneMemberEventNewLocation').value = '大會國際會議廳';
        document.getElementById('cloneMemberEventCopyGuests').checked = true;

        modal.classList.add('active');
    }

    closeCloneMemberEventModal() {
        const modal = document.getElementById('cloneMemberEventModal');
        if (modal) modal.classList.remove('active');
    }

    async handleCloneMemberEventSubmit(e) {
        if (e) e.preventDefault();
        const sourceId = document.getElementById('cloneMemberEventSourceId').value;
        const targetUsername = document.getElementById('cloneMemberEventTargetUsername').value;
        const newName = document.getElementById('cloneMemberEventNewName').value.trim();
        const newDate = document.getElementById('cloneMemberEventNewDate').value;
        const location = document.getElementById('cloneMemberEventNewLocation').value.trim();
        const copyGuests = document.getElementById('cloneMemberEventCopyGuests').checked;

        if (!newName || !newDate) {
            alert('請填寫新活動名稱與活動日期！');
            return;
        }

        try {
            await window.apiService.cloneEvent(sourceId, {
                newEventName: newName,
                newEventDate: new Date(newDate).toISOString(),
                location,
                copyGuests,
                ownerUsername: targetUsername || undefined
            });

            this.showToast(`🎉 成功以範本建立新活動【${newName}】！`, 'success');
            this.closeCloneMemberEventModal();
            if (this.currentManagingMemberUserId) {
                await this.loadMemberEvents(this.currentManagingMemberUserId);
            }
            await this.loadEvents();
            await this.loadMembers();
        } catch (err) {
            alert(err.message || '複製活動範本失敗');
        }
    }

    confirmDeleteMemberEvent(eventId, eventName) {
        this.pendingDeleteMemberEventId = eventId;
        const desc = document.getElementById('deleteMemberEventTargetDesc');
        if (desc) {
            desc.innerHTML = `<strong>場次名稱：</strong>${this.escapeHtml(eventName)}<br><span style="font-size: 12px; color: #991B1B;">代碼：${this.escapeHtml(eventId)}</span>`;
        }
        const modal = document.getElementById('deleteMemberEventConfirmModal');
        if (modal) modal.classList.add('active');
    }

    closeDeleteMemberEventModal() {
        const modal = document.getElementById('deleteMemberEventConfirmModal');
        if (modal) modal.classList.remove('active');
        this.pendingDeleteMemberEventId = null;
    }

    async executeDeleteMemberEvent() {
        if (!this.pendingDeleteMemberEventId) return;
        const eventId = this.pendingDeleteMemberEventId;
        try {
            await window.apiService.deleteEvent(eventId);
            this.showToast('活動及其名冊已永久刪除！', 'info');
            this.closeDeleteMemberEventModal();
            if (this.currentManagingMemberUserId) {
                await this.loadMemberEvents(this.currentManagingMemberUserId);
            }
            if (this.currentEventId === eventId) {
                this.currentEventId = '';
            }
            await this.loadEvents();
            if (this.currentEventId) {
                await this.loadGuestsAndStats();
            } else {
                this.resetStats();
                this.renderAllViews();
            }
            await this.loadMembers();
        } catch (err) {
            alert(err.message || '刪除活動失敗');
        }
    }

    showCreateEventForMemberModal() {
        this.closeMemberEventsModal();
        this.showCreateEventModal();
    }

    async jumpToMemberEvent(eventId) {
        this.currentEventId = eventId;
        this.populateEventSelector();
        this.closeMemberEventsModal();
        this.switchTab('staff');
        await this.loadGuestsAndStats();
        this.showToast('已切換至指定活動場次', 'success');
    }

    // =========================================================================
    // EVENTS & CLONE TEMPLATE (Requirement 3: Annual Org feature)
    // =========================================================================

    async loadEvents() {
        try {
            this.events = await window.apiService.getEvents();
            if (this.events.length > 0) {
                if (!this.currentEventId || !this.events.some(e => e.eventId === this.currentEventId)) {
                    this.currentEventId = this.events[0].eventId;
                }
            } else {
                this.currentEventId = '';
                this.resetStats();
            }
            this.populateEventSelector();
        } catch (err) {
            if (err.message === 'AUTH_REQUIRED') {
                this.showLoginOverlay();
            }
        }
    }

    populateEventSelector() {
        const select = document.getElementById('eventSelect');
        if (!select) return;

        if (this.events.length === 0) {
            select.innerHTML = '<option value="">目前尚無活動場次</option>';
            return;
        }

        select.innerHTML = this.events.map(e => `
          <option value="${e.eventId}" ${e.eventId === this.currentEventId ? 'selected' : ''}>
            ${e.isActive ? '🟢' : '⏸️'} ${this.escapeHtml(e.eventName)} (${new Date(e.eventDate).toLocaleDateString()})
          </option>
        `).join('');
    }

    showCreateEventModal() {
        const user = window.apiService.currentUser;
        if (user && user.role !== 'Admin' && user.planType === 'SingleEvent' && this.events.length >= 1) {
            alert('⚠️ 您目前的【單場活動方案】僅限建立 1 場活動！\n\n如需舉辦多場活動或使用範本複製功能，請升級為【機構年度方案】！');
            return;
        }

        const modal = document.getElementById('createEventModal');
        if (modal) modal.classList.add('active');

        const now = new Date();
        now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
        const dateInp = document.getElementById('createEventDate');
        if (dateInp) dateInp.value = now.toISOString().slice(0, 16);
    }

    closeCreateEventModal() {
        const modal = document.getElementById('createEventModal');
        if (modal) modal.classList.remove('active');
        const form = document.getElementById('createEventForm');
        if (form) form.reset();
    }

    async handleCreateEventSubmit(e) {
        if (e) e.preventDefault();
        const name = document.getElementById('createEventName')?.value.trim();
        const date = document.getElementById('createEventDate')?.value;
        const location = document.getElementById('createEventLocation')?.value.trim();
        const desc = document.getElementById('createEventDesc')?.value.trim();

        if (!name || !date) {
            alert('請輸入活動名稱與時間！');
            return;
        }

        try {
            const created = await window.apiService.createEvent({
                eventName: name,
                eventDate: new Date(date).toISOString(),
                location: location || '大會國際會議廳',
                description: desc,
                isActive: true
            });

            this.showToast(`🎉 活動「${created.eventName}」建立成功！`, 'success');
            this.closeCreateEventModal();
            await this.loadEvents();
            this.currentEventId = created.eventId;
            this.populateEventSelector();
            await this.loadGuestsAndStats();
        } catch (err) {
            alert(err.message || '建立活動失敗');
        }
    }

    showCloneEventModal() {
        const user = window.apiService.currentUser;
        if (user && user.role !== 'Admin' && user.planType === 'SingleEvent') {
            alert('⚠️ 「範本複製」為【機構年度方案】與管理者尊榮專屬功能！\n\n可一鍵複製歷史活動設定、地點與名冊結構，請升級為機構年度方案以享有此功能！');
            return;
        }

        const currentEv = this.events.find(e => e.eventId === this.currentEventId);
        if (!currentEv) {
            alert('⚠️ 目前尚未建立任何活動場次可供複製，請先點擊上方【➕ 建立新活動】！');
            return;
        }

        document.getElementById('cloneEventName').value = `[複製] ${currentEv.eventName}`;
        document.getElementById('cloneEventLocation').value = currentEv.location || '';
        const now = new Date();
        now.setDate(now.getDate() + 7);
        now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
        document.getElementById('cloneEventDate').value = now.toISOString().slice(0, 16);

        const modal = document.getElementById('cloneEventModal');
        if (modal) modal.classList.add('active');
    }

    closeCloneEventModal() {
        const modal = document.getElementById('cloneEventModal');
        if (modal) modal.classList.remove('active');
        const form = document.getElementById('cloneEventForm');
        if (form) form.reset();
    }

    async handleCloneEventSubmit(e) {
        if (e) e.preventDefault();
        const name = document.getElementById('cloneEventName')?.value.trim();
        const date = document.getElementById('cloneEventDate')?.value;
        const location = document.getElementById('cloneEventLocation')?.value.trim();
        const copyGuests = document.getElementById('cloneEventCopyGuests')?.checked || false;

        if (!name || !date) {
            alert('請輸入新活動名稱與日期！');
            return;
        }

        try {
            const cloned = await window.apiService.cloneEvent(this.currentEventId, {
                newEventName: name,
                newEventDate: new Date(date).toISOString(),
                location,
                copyGuests
            });

            this.showToast(`🎉 活動範本「${cloned.eventName}」複製成功！`, 'success');
            this.closeCloneEventModal();
            await this.loadEvents();
            this.currentEventId = cloned.eventId;
            this.populateEventSelector();
            await this.loadGuestsAndStats();
        } catch (err) {
            alert(err.message || '複製活動失敗');
        }
    }

    showDeleteEventConfirmModal() {
        const currentEv = this.events.find(e => e.eventId === this.currentEventId);
        if (!currentEv) return;

        this.pendingDeleteEventId = this.currentEventId;
        const descBox = document.getElementById('deleteEventConfirmTargetDesc');
        if (descBox) {
            descBox.innerHTML = `即將刪除：<strong>${this.escapeHtml(currentEv.eventName)}</strong><br><span style="font-size:12px;color:var(--text-muted);">活動時間：${new Date(currentEv.eventDate).toLocaleDateString()} | 名冊總數：${this.guests.length} 人</span>`;
        }

        const modal = document.getElementById('deleteEventConfirmModal');
        if (modal) modal.classList.add('active');
    }

    closeDeleteEventModal() {
        const modal = document.getElementById('deleteEventConfirmModal');
        if (modal) modal.classList.remove('active');
        this.pendingDeleteEventId = null;
    }

    async executeDeleteEvent() {
        if (!this.pendingDeleteEventId) return;
        try {
            await window.apiService.deleteEvent(this.pendingDeleteEventId);
            this.showToast('活動已刪除', 'success');
            this.closeDeleteEventModal();
            this.currentEventId = '';
            await this.loadEvents();
            if (this.currentEventId) {
                await this.loadGuestsAndStats();
            } else {
                this.resetStats();
                this.renderAllViews();
            }
        } catch (err) {
            alert(err.message || '刪除活動失敗');
        }
    }

    showToggleEventActiveModal() {
        const currentEv = this.events.find(e => e.eventId === this.currentEventId);
        if (!currentEv) return;

        this.pendingToggleActiveEventId = this.currentEventId;
        const title = document.getElementById('toggleEventModalTitle');
        const desc = document.getElementById('toggleEventTargetDesc');

        if (title) title.innerText = currentEv.isActive ? '確定要停用此活動場次嗎？' : '確定要重新啟用此活動場次嗎？';
        if (desc) desc.innerText = `活動名稱：${currentEv.eventName}`;

        const modal = document.getElementById('toggleEventActiveModal');
        if (modal) modal.classList.add('active');
    }

    closeToggleEventActiveModal() {
        const modal = document.getElementById('toggleEventActiveModal');
        if (modal) modal.classList.remove('active');
        this.pendingToggleActiveEventId = null;
    }

    async executeToggleEventActive() {
        if (!this.pendingToggleActiveEventId) return;
        const currentEv = this.events.find(e => e.eventId === this.pendingToggleActiveEventId);
        if (!currentEv) return;

        try {
            await window.apiService.toggleEventActive(this.pendingToggleActiveEventId, !currentEv.isActive);
            this.showToast(`活動狀態已變更為：${!currentEv.isActive ? '啟用' : '停用'}`, 'info');
            this.closeToggleEventActiveModal();
            await this.loadEvents();
        } catch (err) {
            alert(err.message || '變更狀態失敗');
        }
    }

    // =========================================================================
    // GUESTS & STATS
    // =========================================================================

    resetStats() {
        const user = window.apiService.currentUser;
        const maxCap = user?.maxGuestsPerEvent || 500;
        this.guests = [];
        this.stats = {
            totalGuests: 0,
            checkedInCount: 0,
            pendingCount: 0,
            attendanceRate: 0,
            vipTotal: 0,
            vipCheckedIn: 0,
            vipAttendanceRate: 0,
            maxGuestsAllowed: maxCap
        };
    }

    async loadGuestsAndStats() {
        if (!this.currentEventId) {
            this.resetStats();
            this.renderAllViews();
            return;
        }
        try {
            this.guests = await window.apiService.getGuests(this.currentEventId);
            this.stats = await window.apiService.getStats(this.currentEventId) || this.stats;
            this.renderAllViews();
        } catch (err) {
            if (err.message === 'AUTH_REQUIRED') {
                this.showLoginOverlay();
            }
        }
    }

    updateStatsLocally() {
        const total = this.guests.length;
        const checked = this.guests.filter(g => g.isCheckedIn).length;
        const pending = total - checked;
        const rate = total > 0 ? Math.round((checked / total) * 1000) / 10 : 0;

        const vips = this.guests.filter(g => g.rankWeight <= 2);
        const vipTotal = vips.length;
        const vipChecked = vips.filter(g => g.isCheckedIn).length;
        const vipRate = vipTotal > 0 ? Math.round((vipChecked / vipTotal) * 1000) / 10 : 0;

        this.stats = {
            totalGuests: total,
            checkedInCount: checked,
            pendingCount: pending,
            attendanceRate: rate,
            vipTotal,
            vipCheckedIn: vipChecked,
            vipAttendanceRate: vipRate,
            maxGuestsAllowed: this.stats?.maxGuestsAllowed || 500
        };

        this.renderStatsStrip();
    }

    renderAllViews() {
        this.updateNameMaskToggleButtons();
        this.renderStatsStrip();
        this.renderStaffGuests();
        this.renderHostView();
        this.renderAdminSpecs();
    }

    /**
     * 姓名資訊遮蔽處理函式
     * 2字: 張*
     * 3字: 張*宇
     * 4字: 馬**翰
     * 5字以上: 第一個字+*+最後一個字
     */
    maskName(name) {
        if (!name || typeof name !== 'string') return name || '';
        if (!this.isNameMasked) return name;

        const str = name.trim();
        if (str.length <= 1) return str;
        if (str.length === 2) {
            return str[0] + '*';
        }
        if (str.length === 3) {
            return str[0] + '*' + str[2];
        }
        if (str.length === 4) {
            return str[0] + '**' + str[3];
        }
        return str[0] + '*'.repeat(str.length - 2) + str[str.length - 1];
    }

    toggleNameMask() {
        this.isNameMasked = !this.isNameMasked;
        localStorage.setItem('inpoint_name_masked', this.isNameMasked ? 'true' : 'false');
        this.updateNameMaskToggleButtons();
        this.renderAllViews();

        if (this.isNameMasked) {
            this.showToast('🔒 姓名資訊已進行安全遮蔽防護！', 'info');
        } else {
            this.showToast('👁️ 姓名資訊已切換為完整顯示', 'info');
        }
    }

    updateNameMaskToggleButtons() {
        const btns = document.querySelectorAll('.btn-name-mask-toggle');
        btns.forEach(btn => {
            if (this.isNameMasked) {
                btn.classList.add('is-masked');
                btn.innerHTML = '<span>🔒 姓名遮蔽：開啟</span>';
                btn.title = '點擊關閉遮蔽（顯示全名）';
            } else {
                btn.classList.remove('is-masked');
                btn.innerHTML = '<span>👁️ 顯示全名</span>';
                btn.title = '點擊開啟姓名遮蔽（安全防護）';
            }
        });
    }

    renderStatsStrip() {
        const totalEl = document.getElementById('statTotalGuests');
        const checkedEl = document.getElementById('statCheckedIn');
        const pendingEl = document.getElementById('statPending');
        const rateEl = document.getElementById('statAttendanceRate');
        const progressEl = document.getElementById('statProgressFill');
        const vipRatioEl = document.getElementById('statVipRatio');
        const vipProgressEl = document.getElementById('statVipProgressFill');
        const capacityMetaEl = document.getElementById('statCapacityMeta');

        const s = this.stats || {
            totalGuests: 0,
            checkedInCount: 0,
            pendingCount: 0,
            attendanceRate: 0,
            vipTotal: 0,
            vipCheckedIn: 0,
            vipAttendanceRate: 0
        };

        if (totalEl) totalEl.innerText = s.totalGuests;
        if (checkedEl) checkedEl.innerText = s.checkedInCount;
        if (pendingEl) pendingEl.innerText = s.pendingCount;
        if (rateEl) rateEl.innerText = `${s.attendanceRate}%`;
        if (progressEl) progressEl.style.width = `${Math.min(100, s.attendanceRate)}%`;
        if (vipRatioEl) vipRatioEl.innerText = `${s.vipCheckedIn} / ${s.vipTotal}`;
        if (vipProgressEl) vipProgressEl.style.width = `${Math.min(100, s.vipAttendanceRate)}%`;

        if (capacityMetaEl) {
            const user = window.apiService.currentUser;
            const maxCap = user?.maxGuestsPerEvent || 500;
            if (this.events.length === 0 || !this.currentEventId) {
                capacityMetaEl.innerText = `尚未建立活動 (上限 ${maxCap} 人)`;
            } else {
                capacityMetaEl.innerText = `上限 ${maxCap} 人 (目前 ${s.totalGuests})`;
            }
        }

        // Chip counts
        const countAll = document.getElementById('countAll');
        const countChecked = document.getElementById('countChecked');
        const countPending = document.getElementById('countPending');
        const countVip = document.getElementById('countVip');

        if (countAll) countAll.innerText = s.totalGuests;
        if (countChecked) countChecked.innerText = s.checkedInCount;
        if (countPending) countPending.innerText = s.pendingCount;
        if (countVip) countVip.innerText = s.vipTotal;
    }

    renderStaffGuests() {
        const grid = document.getElementById('guestCardsGrid');
        const emptyBox = document.getElementById('guestCardsEmpty');
        if (!grid) return;

        let filtered = this.guests;

        // 1. Filter by chip
        if (this.activeFilter === 'checked') {
            filtered = filtered.filter(g => g.isCheckedIn);
        } else if (this.activeFilter === 'pending') {
            filtered = filtered.filter(g => !g.isCheckedIn);
        } else if (this.activeFilter === 'vip') {
            filtered = filtered.filter(g => g.rankWeight <= 2 || (g.title && (g.title.includes('院長') || g.title.includes('局長') || g.title.includes('部長') || g.title.includes('副院長') || g.title.includes('民代') || g.title.includes('照專') || g.title.includes('督導') || g.title.includes('特級') || g.title.includes('VIP'))));
        }

        // 2. Filter by search query
        if (this.searchQuery) {
            filtered = filtered.filter(g =>
                (g.name && g.name.toLowerCase().includes(this.searchQuery)) ||
                (g.guestId && g.guestId.toLowerCase().includes(this.searchQuery)) ||
                (g.organization && g.organization.toLowerCase().includes(this.searchQuery)) ||
                (g.title && g.title.toLowerCase().includes(this.searchQuery)) ||
                (g.tableNo && g.tableNo.toLowerCase().includes(this.searchQuery)) ||
                (g.notes && g.notes.toLowerCase().includes(this.searchQuery)) ||
                (g.phone && g.phone.includes(this.searchQuery))
            );
        }

        if (filtered.length === 0) {
            grid.innerHTML = '';
            if (emptyBox) {
                emptyBox.style.display = 'block';
                if (this.events.length === 0 || !this.currentEventId) {
                    emptyBox.innerHTML = `
                      <div style="font-size: 36px; margin-bottom: 8px;">📭</div>
                      <div style="font-size: 15px; font-weight: 700; color: var(--text-charcoal); margin-bottom: 4px;">目前尚未建立任何活動場次</div>
                      <div style="font-size: 13px; color: var(--text-muted);">請點擊上方【➕ 建立新活動】開始建立您的活動與名冊。</div>
                    `;
                } else {
                    emptyBox.innerHTML = `
                      <div style="font-size: 28px; margin-bottom: 6px;">🔍</div>
                      <div style="font-size: 14px; font-weight: 700; color: var(--text-charcoal); margin-bottom: 4px;">查無相符之貴賓名單</div>
                      <div style="font-size: 12px; color: var(--text-muted);">請嘗試不同的關鍵字搜尋，或點擊「現場新增貴賓 / 一鍵匯入 Excel」建立資料。</div>
                    `;
                }
            }
            return;
        }

        if (emptyBox) emptyBox.style.display = 'none';

        grid.innerHTML = filtered.map(g => {
            // 1. Rank Badge matching screenshot
            let rankBadgeHtml = '';
            if (g.rankWeight === 1 || (g.title && (g.title.includes('院長') || g.title.includes('局長') || g.title.includes('部長') || g.title.includes('董事長') || g.title.includes('署長')))) {
                rankBadgeHtml = `<span class="rank-badge rank-vip-1">🏅 院長/局長 (VIP-1)</span>`;
            } else if (g.rankWeight === 2 || (g.title && (g.title.includes('副院長') || g.title.includes('民代') || g.title.includes('議員') || g.title.includes('副局長') || g.title.includes('照專') || g.title.includes('督導')))) {
                rankBadgeHtml = `<span class="rank-badge rank-vip-2">🏅 副院長/民代/照專督導 (VIP-2)</span>`;
            } else if (g.rankWeight === 3 || (g.title && (g.title.includes('主任') || g.title.includes('教授') || g.title.includes('科長') || g.title.includes('處長') || g.title.includes('醫檢師')))) {
                rankBadgeHtml = `<span class="rank-badge rank-vip-3">🏅 科部主任/教授</span>`;
            } else {
                rankBadgeHtml = `<span class="rank-badge rank-general">嘉賓同仁</span>`;
            }

            // 2. Table / Seat Badge matching screenshot
            let tableBadgeHtml = '';
            const t = (g.tableNo || '').trim();
            if (!t || t === '-' || t === '未排桌') {
                tableBadgeHtml = `<span class="table-badge table-unassigned">🪑 未排桌</span>`;
            } else {
                tableBadgeHtml = `<span class="table-badge table-assigned">🪑 ${this.escapeHtml(t)}</span>`;
            }

            // 3. Organization & Title matching screenshot
            let orgTitleText = '';
            const org = (g.organization || '').trim();
            const title = (g.title || '').trim();
            if (org && title) {
                orgTitleText = `${this.escapeHtml(org)} ‧ ${this.escapeHtml(title)}`;
            } else if (org) {
                orgTitleText = `${this.escapeHtml(org)} ‧ 貴賓`;
            } else if (title) {
                orgTitleText = `貴賓 ‧ ${this.escapeHtml(title)}`;
            } else {
                orgTitleText = '貴賓同仁';
            }

            // 4. Notes / Contact pill
            let notesHtml = '';
            if (g.notes && g.notes.trim()) {
                const text = g.notes.trim();
                const dispText = text.startsWith('聯絡人') ? text : `聯絡人：${text}`;
                notesHtml = `<div class="guest-contact-pill">📌 ${this.escapeHtml(dispText)}</div>`;
            } else if (g.phone && g.phone.trim()) {
                notesHtml = `<div class="guest-contact-pill">📞 ${this.escapeHtml(g.phone.trim())}</div>`;
            }

            // 5. Check-in Timestamp & Status
            let checkInStatusHtml = '';
            if (g.isCheckedIn) {
                let timeStr = '';
                if (g.checkedInAt) {
                    const d = new Date(g.checkedInAt);
                    if (!isNaN(d.getTime())) {
                        timeStr = d.toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit' });
                    }
                }
                const byStr = g.checkedInBy || '現場報到處櫃檯 A';
                if (timeStr) {
                    checkInStatusHtml = `<span class="checkin-time-text">已於 ${timeStr} 報到 (${this.escapeHtml(byStr)})</span>`;
                } else {
                    checkInStatusHtml = `<span class="checkin-time-text">已完成報到 (${this.escapeHtml(byStr)})</span>`;
                }
            } else {
                checkInStatusHtml = `<span class="checkin-pending-text">尚未完成報到</span>`;
            }

            // 6. Action Buttons matching screenshot
            const checkInBtnHtml = g.isCheckedIn
                ? `<button type="button" class="btn-checkin-toggle is-checked" onclick="app.toggleCheckIn('${g.guestId}', false)" title="點擊可撤回報到">✓ 已報到 (點擊撤回)</button>`
                : `<button type="button" class="btn-checkin-toggle is-pending" onclick="app.toggleCheckIn('${g.guestId}', true)" title="點擊進行一鍵報到">⚡ 點擊報到</button>`;

            const deleteBtnHtml = `<button type="button" class="btn-card-delete" onclick="app.showDeleteGuestModal('${g.guestId}', '${this.escapeHtml(this.maskName(g.name))}')" title="刪除此貴賓">🗑️</button>`;

            return `
              <div class="guest-card ${g.isCheckedIn ? 'is-checked-in' : ''}" data-guest-id="${g.guestId}">
                <div class="guest-card-header">
                  <div class="guest-name-badge-group">
                    <span class="guest-name">${this.escapeHtml(this.maskName(g.name))}</span>
                    ${rankBadgeHtml}
                  </div>
                  ${tableBadgeHtml}
                </div>

                <div class="guest-org-title">${orgTitleText}</div>

                ${notesHtml}

                <div class="guest-meta-row">
                  <span class="guest-code">編號：${this.escapeHtml(g.guestId)}</span>
                  ${checkInStatusHtml}
                </div>

                <div class="guest-card-actions">
                  ${checkInBtnHtml}
                  ${deleteBtnHtml}
                </div>
              </div>
            `;
        }).join('');
    }

    // =========================================================================
    // VIP HOST ANNOUNCEMENTS (唱名管理：未唱名置頂，已唱名移至最後)
    // =========================================================================

    loadAnnouncedGuests() {
        if (!this.currentEventId) {
            this.announcedGuests = new Set();
            return;
        }
        try {
            const key = `inpoint_announced_${this.currentEventId}`;
            const raw = localStorage.getItem(key);
            if (raw) {
                const parsed = JSON.parse(raw);
                this.announcedGuests = new Set(Array.isArray(parsed) ? parsed : []);
            } else {
                this.announcedGuests = new Set();
            }
        } catch (e) {
            this.announcedGuests = new Set();
        }
    }

    saveAnnouncedGuests() {
        if (!this.currentEventId) return;
        try {
            const key = `inpoint_announced_${this.currentEventId}`;
            localStorage.setItem(key, JSON.stringify(Array.from(this.announcedGuests)));
        } catch (e) {
            console.warn('saveAnnouncedGuests failed:', e);
        }
    }

    toggleAnnounce(guestId, forceStatus = null) {
        this.loadAnnouncedGuests();
        const isCurrentlyAnnounced = this.announcedGuests.has(guestId);
        const targetStatus = forceStatus !== null ? forceStatus : !isCurrentlyAnnounced;
        const guest = this.guests.find(g => g.guestId === guestId);
        const guestDisplayName = guest ? `【${guest.title ? guest.title + ' ' : ''}${this.maskName(guest.name)}】` : '長官';

        if (targetStatus) {
            this.announcedGuests.add(guestId);
            this.saveAnnouncedGuests();
            if (window.soundManager) {
                window.soundManager.playVipFanfare();
            }
            this.showToast(`📢 已完成 ${guestDisplayName} 唱名歡迎！已移至名單後方。`, 'success');
        } else {
            this.announcedGuests.delete(guestId);
            this.saveAnnouncedGuests();
            if (window.soundManager) {
                window.soundManager.playUndoSound();
            }
            this.showToast(`已撤回 ${guestDisplayName} 唱名狀態，已移回待唱名清單。`, 'info');
        }

        this.renderHostView();
    }

    resetAllAnnounced() {
        this.loadAnnouncedGuests();
        if (this.announcedGuests.size === 0) {
            this.showToast('目前尚無已唱名長官記錄', 'info');
            return;
        }
        if (confirm('確定要重設本場活動所有長官的唱名狀態嗎？已唱名長官將全數移回待唱名名單。')) {
            this.announcedGuests.clear();
            this.saveAnnouncedGuests();
            if (window.soundManager) {
                window.soundManager.playUndoSound();
            }
            this.showToast('已重設所有長官唱名狀態！', 'success');
            this.renderHostView();
        }
    }

    refreshHostView() {
        this.loadGuestsAndStats().then(() => {
            this.showToast('🔄 主持人 VIP 戰情看板已即時同步最新到場數據！', 'success');
        });
    }

    renderHostView() {
        this.loadAnnouncedGuests();

        const arrivedList = document.getElementById('hostArrivedList');
        const pendingList = document.getElementById('hostPendingList');
        const arrivedCount = document.getElementById('hostArrivedCount');
        const pendingCount = document.getElementById('hostPendingCount');

        const m1 = document.getElementById('miniVip1Stat');
        const m2 = document.getElementById('miniVip2Stat');
        const m3 = document.getElementById('miniVip3Stat');
        const mr = document.getElementById('miniVipRateStat');
        const ma = document.getElementById('miniVipAnnounceStat');

        if (!this.currentEventId || this.events.length === 0) {
            if (arrivedList) {
                arrivedList.innerHTML = `
                  <div class="host-empty-box">
                    <div style="font-size: 28px; margin-bottom: 6px;">📭</div>
                    <div style="font-weight: 700; color: var(--text-charcoal);">目前尚未建立任何活動場次</div>
                    <div style="font-size: 12px; margin-top: 4px;">請點擊上方【➕ 建立新活動】開始建立活動並匯入長官貴賓名單。</div>
                  </div>
                `;
            }
            if (pendingList) {
                pendingList.innerHTML = `
                  <div class="host-empty-box">
                    <div style="font-size: 28px; margin-bottom: 6px;">📭</div>
                    <div style="font-weight: 700; color: var(--text-charcoal);">目前尚未建立任何活動場次</div>
                  </div>
                `;
            }
            if (m1) m1.innerText = `0 / 0`;
            if (m2) m2.innerText = `0 / 0`;
            if (m3) m3.innerText = `0 / 0`;
            if (mr) mr.innerText = `0%`;
            if (ma) ma.innerText = `0 / 0`;
            if (arrivedCount) arrivedCount.innerText = `0 位`;
            if (pendingCount) pendingCount.innerText = `0 位`;
            return;
        }

        const getGuestRank = (g) => {
            let r = parseInt(g.rankWeight !== undefined ? g.rankWeight : (g.RankWeight !== undefined ? g.RankWeight : null), 10);
            if (!isNaN(r) && r >= 1 && r <= 4) return r;
            const title = (g.title || '').trim();
            if (/院長|局長|部長|署長|董事長|總裁|副部長|校長/.test(title)) return 1;
            if (/副院長|副局長|議員|立委|代表|組長|科長|副署長|委員|督導|照專/.test(title)) return 2;
            if (/主任|教授|醫師|處長|顧問|隊長|副主任|總監|學者|專家|講師/.test(title)) return 3;
            return 4;
        };

        const isGuestCheckedIn = (g) => {
            return g.isCheckedIn === true || g.isCheckedIn === 'true' || g.isCheckedIn === 1 || g.isCheckedIn === '1' ||
                   g.IsCheckedIn === true || g.IsCheckedIn === 'true' || g.IsCheckedIn === 1 || g.IsCheckedIn === '1';
        };

        const allGuests = this.guests || [];
        const vip1 = allGuests.filter(g => getGuestRank(g) === 1);
        const vip2 = allGuests.filter(g => getGuestRank(g) === 2);
        const vip3 = allGuests.filter(g => getGuestRank(g) === 3);
        const allVips = allGuests.filter(g => getGuestRank(g) <= 3);

        const rawArrivedVips = allVips.filter(g => isGuestCheckedIn(g));
        const pendingVips = allVips.filter(g => !isGuestCheckedIn(g)).sort((a, b) => getGuestRank(a) - getGuestRank(b));

        // Sort arrived VIPs:
        // 1. Unannounced (0) FIRST, Announced (1) MOVED TO LAST (已唱名的長官移至最後)
        // 2. Rank Weight ASC (VIP-1 -> VIP-2 -> VIP-3)
        // 3. CheckedInAt DESC (Newest arrival first)
        const arrivedVips = [...rawArrivedVips].sort((a, b) => {
            const aAnnounced = this.announcedGuests.has(a.guestId) ? 1 : 0;
            const bAnnounced = this.announcedGuests.has(b.guestId) ? 1 : 0;
            if (aAnnounced !== bAnnounced) {
                return aAnnounced - bAnnounced; // 0 (unannounced) before 1 (announced)
            }
            if (getGuestRank(a) !== getGuestRank(b)) {
                return getGuestRank(a) - getGuestRank(b);
            }
            const aTime = a.checkedInAt ? new Date(a.checkedInAt).getTime() : 0;
            const bTime = b.checkedInAt ? new Date(b.checkedInAt).getTime() : 0;
            return bTime - aTime;
        });

        const unannouncedVips = arrivedVips.filter(g => !this.announcedGuests.has(g.guestId));
        const announcedVips = arrivedVips.filter(g => this.announcedGuests.has(g.guestId));

        // Update Mini Stats Bar
        const vip1Checked = vip1.filter(g => isGuestCheckedIn(g)).length;
        const vip2Checked = vip2.filter(g => isGuestCheckedIn(g)).length;
        const vip3Checked = vip3.filter(g => isGuestCheckedIn(g)).length;
        const totalVipChecked = rawArrivedVips.length;
        const totalVip = allVips.length;
        const vipRate = totalVip > 0 ? Math.round((totalVipChecked / totalVip) * 1000) / 10 : 0;
        if (m1) m1.innerText = `${vip1Checked} / ${vip1.length}`;
        if (m2) m2.innerText = `${vip2Checked} / ${vip2.length}`;
        if (m3) m3.innerText = `${vip3Checked} / ${vip3.length}`;
        if (mr) mr.innerText = `${vipRate}%`;
        if (ma) ma.innerText = `${announcedVips.length} / ${arrivedVips.length}`;

        if (arrivedCount) {
            if (unannouncedVips.length > 0) {
                arrivedCount.innerHTML = `📢 待唱名 <strong>${unannouncedVips.length}</strong> 位 / 共 ${arrivedVips.length} 位`;
            } else if (arrivedVips.length > 0) {
                arrivedCount.innerHTML = `✓ 全數完成唱名 (${arrivedVips.length} 位)`;
            } else {
                arrivedCount.innerText = `0 位`;
            }
        }
        if (pendingCount) pendingCount.innerText = `${pendingVips.length} 位`;

        if (arrivedList) {
            if (arrivedVips.length === 0) {
                arrivedList.innerHTML = `
                  <div class="host-empty-box">
                    <div style="font-size: 28px; margin-bottom: 6px;">📲</div>
                    <div style="font-weight: 700; color: var(--text-charcoal);">尚無 VIP 長官完成報到</div>
                    <div style="font-size: 12px; margin-top: 4px;">現場長官完成手機掃碼或櫃檯簽到後，將即時顯示於此看板。</div>
                  </div>
                `;
            } else {
                let hasRenderedDivider = false;

                arrivedList.innerHTML = arrivedVips.map((g, idx) => {
                    const isAnnounced = this.announcedGuests.has(g.guestId);
                    const rank = getGuestRank(g);
                    const vipClass = rank === 1 ? 'vip1' : (rank === 2 ? 'vip2' : 'vip3');
                    const badgeText = rank === 1 ? '👑 院長/局長 (VIP-1)' : (rank === 2 ? '⭐ 副院長/民代/照專督導 (VIP-2)' : '🎓 科部主任 (VIP-3)');
                    
                    let timeFormatted = '已完成簽到';
                    if (g.checkedInAt) {
                        const d = new Date(g.checkedInAt);
                        timeFormatted = `下午 ${d.toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}`;
                    }

                    let speechCue = `🎙️ 提詞建議：長官已到場就座，可請貴賓準備致詞或引言。`;
                    if (isAnnounced) {
                        speechCue = `🎙️ 提詞備註：【${this.escapeHtml(g.title)} ${this.escapeHtml(this.maskName(g.name))}】已完成現場唱名致意，現於席位【${this.escapeHtml(g.tableNo || '貴賓席')}】就座。`;
                    } else if (rank === 1) {
                        speechCue = `🎙️ 致詞提詞：【${this.escapeHtml(g.title)} ${this.escapeHtml(this.maskName(g.name))}】已就席長官主桌，可安排大會開場致詞。`;
                    } else if (rank === 2) {
                        speechCue = `🎙️ 致詞提詞：【${this.escapeHtml(g.title)} ${this.escapeHtml(this.maskName(g.name))}】已到場，可安排貴賓致詞引言或座談指導。`;
                    } else if (rank === 3) {
                        speechCue = `🎙️ 接待提詞：【${this.escapeHtml(g.title)} ${this.escapeHtml(this.maskName(g.name))}】已就席【${this.escapeHtml(g.tableNo || '貴賓席')}】。`;
                    }

                    const staffBadge = g.checkedInBy ? `<span style="font-size:11.5px; color:#64748B;">經手：${this.escapeHtml(g.checkedInBy)}</span>` : '';

                    const announceBtnHtml = isAnnounced
                        ? `<button type="button" class="btn-announce btn-announced" onclick="app.toggleAnnounce('${g.guestId}', false)" title="已完成唱名，點擊可撤回重設">
                             <span>✓ 已唱名 (撤回)</span>
                           </button>`
                        : `<button type="button" class="btn-announce btn-ready-announce" onclick="app.toggleAnnounce('${g.guestId}', true)" title="點擊進行唱名歡迎並移至名單後方">
                             <span>📢 唱名歡迎</span>
                           </button>`;

                    const statusBadgeHtml = isAnnounced
                        ? `<span class="host-status-announced-badge">✓ 已唱名</span>`
                        : `<span class="host-status-arrived-badge">✓ 已就座</span>`;

                    let dividerHtml = '';
                    if (isAnnounced && !hasRenderedDivider && unannouncedVips.length > 0) {
                        hasRenderedDivider = true;
                        dividerHtml = `
                          <div class="host-announced-section-divider">
                            <span>✓ 以下為已完成唱名長官 (共 ${announcedVips.length} 位，已移至最後)</span>
                          </div>
                        `;
                    }

                    return `
                      ${dividerHtml}
                      <div class="host-vip-card ${vipClass} ${isAnnounced ? 'is-announced' : 'is-unannounced'}" data-guest-id="${g.guestId}">
                        <div class="host-vip-card-header">
                          <div class="host-vip-header-left">
                            <span class="host-vip-badge ${vipClass}">${badgeText}</span>
                            <div class="host-vip-name-row">
                              <span class="host-vip-name">${this.escapeHtml(this.maskName(g.name))}</span>
                              <span class="host-vip-role-tag">${this.escapeHtml(g.title)}</span>
                              <span class="host-vip-org-badge">【${this.escapeHtml(g.organization)}】</span>
                            </div>
                          </div>
                          <div class="host-vip-header-actions">
                            ${statusBadgeHtml}
                            ${announceBtnHtml}
                          </div>
                        </div>
                        <div class="host-vip-meta-tags">
                          <span class="host-meta-seat">🍽️ 安排席位：<strong>${this.escapeHtml(g.tableNo || '未排桌')}</strong></span>
                          <span class="host-meta-time">⏱️ 抵達時間：${timeFormatted}</span>
                          ${staffBadge}
                        </div>
                        <div class="host-vip-speech-cue ${isAnnounced ? 'is-announced-cue' : ''}">
                          ${speechCue}
                        </div>
                      </div>
                    `;
                }).join('');
            }
        }

        if (pendingList) {
            if (pendingVips.length === 0) {
                pendingList.innerHTML = `
                  <div class="host-empty-celebration">
                    <div style="font-size: 32px; margin-bottom: 6px;">🎉</div>
                    <div style="font-size: 16px; font-weight: 900; color: #92400E;">本場活動所有特邀 VIP 長官已全數到齊！</div>
                    <div style="font-size: 13px; color: #B45309; margin-top: 4px;">現場出席率圓滿達成，司儀與主持人可隨時引導進入大會開場程序。</div>
                  </div>
                `;
            } else {
                pendingList.innerHTML = pendingVips.map(g => {
                    const rank = getGuestRank(g);
                    const vipClass = rank === 1 ? 'vip1' : (rank === 2 ? 'vip2' : 'vip3');
                    const badgeText = rank === 1 ? '👑 院長/局長 (VIP-1)' : (rank === 2 ? '⭐ 副院長/民代/照專督導 (VIP-2)' : '🎓 科部主任 (VIP-3)');

                    return `
                      <div class="host-vip-card ${vipClass}" style="border-style: dashed;">
                        <div class="host-vip-card-header">
                          <div class="host-vip-header-left">
                            <span class="host-vip-badge ${vipClass}">${badgeText}</span>
                            <div class="host-vip-name-row">
                              <span class="host-vip-name">${this.escapeHtml(this.maskName(g.name))}</span>
                              <span class="host-vip-role-tag">${this.escapeHtml(g.title)}</span>
                              <span class="host-vip-org-badge">【${this.escapeHtml(g.organization)}】</span>
                            </div>
                          </div>
                          <button type="button" class="btn btn-primary" style="font-size: 12px; padding: 4px 12px; border-radius: var(--radius-pill); font-weight: 700;" onclick="app.toggleCheckIn('${g.guestId}', true)">
                            ⚡ 櫃檯一鍵簽到
                          </button>
                        </div>
                        <div class="host-vip-meta-tags">
                          <span class="host-meta-seat" style="background:#FFFBEB; color:#B45309; border-color:#FDE68A;">
                            🍽️ 預定席位：<strong>${this.escapeHtml(g.tableNo || '未排桌')}</strong>
                          </span>
                          ${g.phone ? `<span class="host-meta-time">📞 聯絡電話：${this.escapeHtml(g.phone)}</span>` : ''}
                        </div>
                      </div>
                    `;
                }).join('');
            }
        }
    }

    renderAdminSpecs() {
        const box = document.getElementById('currentEventDetailsBox');
        const nameEl = document.getElementById('adminEventNameDisplay');
        const statusEl = document.getElementById('adminEventStatusTag');
        const actionsBar = document.getElementById('adminEventActionsBar');
        if (!box) return;

        const ev = this.events.find(e => e.eventId === this.currentEventId);
        if (!ev) {
            box.innerHTML = `
              <div style="text-align: center; padding: 36px 16px; color: var(--text-muted);">
                <div style="font-size: 32px; margin-bottom: 8px;">📭</div>
                <div style="font-size: 15px; font-weight: 700; color: var(--text-charcoal);">目前尚未建立任何活動場次</div>
                <div style="font-size: 12px; margin-top: 4px;">請點擊上方【➕ 建立新活動】開始建立活動與匯出名冊。</div>
              </div>
            `;
            if (nameEl) nameEl.textContent = '尚未建立活動';
            if (statusEl) {
                statusEl.className = 'admin-event-status-tag inactive';
                statusEl.textContent = '⚪ 無進行中活動';
            }
            if (actionsBar) actionsBar.style.display = 'none';
            return;
        }

        if (actionsBar) actionsBar.style.display = 'flex';
        if (nameEl) nameEl.textContent = ev.eventName;
        if (statusEl) {
            statusEl.className = `admin-event-status-tag ${ev.isActive ? 'active' : 'inactive'}`;
            statusEl.textContent = ev.isActive ? '🟢 現場報到中 (接收多端簽到)' : '⏸️ 已停用 (封存唯讀)';
        }

        const totalGuests = this.guests.length;
        const checkedCount = this.guests.filter(g => g.isCheckedIn).length;
        const rate = totalGuests > 0 ? Math.round((checkedCount / totalGuests) * 1000) / 10 : 0;
        const dateStr = ev.eventDate ? new Date(ev.eventDate).toLocaleDateString('zh-TW', { year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '未設定';

        box.innerHTML = `
          <div class="admin-event-specs-grid">
            <div class="admin-spec-box">
              <div class="label">🗓️ 活動日期時間</div>
              <div class="val">${dateStr}</div>
            </div>
            <div class="admin-spec-box">
              <div class="label">📍 舉辦會場地點</div>
              <div class="val">${this.escapeHtml(ev.location || '大會國際會議廳')}</div>
            </div>
            <div class="admin-spec-box">
              <div class="label">👥 貴賓名冊建檔數</div>
              <div class="val">${totalGuests} 位 / 上限 500 人</div>
            </div>
            <div class="admin-spec-box">
              <div class="label">📊 現場即時出席率</div>
              <div class="val" style="color: #059669;">${checkedCount} 人已到場 (${rate}%)</div>
            </div>
          </div>
          ${ev.description ? `<div style="font-size: 13px; color: #64748B; background: #F8FAF9; padding: 10px 14px; border-radius: 8px; border: 1px solid #E2EDE7; margin-bottom: 16px;">📝 <strong>活動簡介：</strong>${this.escapeHtml(ev.description)}</div>` : ''}
        `;
    }

    // =========================================================================
    // SEARCH & CHECK-IN
    // =========================================================================

    async handleSearchCheckIn() {
        const query = this.searchQuery;
        if (!query) return;

        const match = this.guests.find(g =>
            g.guestId.toLowerCase() === query ||
            g.guestId.toLowerCase().replace(/^0+/, '') === query.replace(/^0+/, '') ||
            (g.phone && g.phone.endsWith(query)) ||
            g.name.toLowerCase() === query
        );

        if (match) {
            await this.toggleCheckIn(match.guestId, true);
            this.clearSearchInput();
        } else {
            this.showToast(`查無與「${query}」相符之貴賓`, 'warning');
        }
    }

    clearSearchInput() {
        const input = document.getElementById('searchInput');
        if (input) input.value = '';
        this.searchQuery = '';
        this.renderStaffGuests();
    }

    async toggleCheckIn(guestId, targetStatus) {
        try {
            const user = window.apiService.currentUser;
            const staff = user ? `${user.displayName || user.username} (工作台)` : '現場報到櫃檯';
            await window.apiService.toggleCheckIn(this.currentEventId, guestId, targetStatus, staff);
            const target = this.guests.find(g => g.guestId === guestId);
            if (target) {
                target.isCheckedIn = targetStatus;
                target.checkedInAt = targetStatus ? new Date().toISOString() : null;
                this.updateStatsLocally();
                this.renderAllViews();
            }
        } catch (err) {
            alert(err.message || '簽到狀態更新失敗');
        }
    }

    showVipArrivalToast(guest) {
        const container = document.getElementById('vipToastContainer');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = 'vip-toast';
        toast.innerHTML = `
          <div style="font-size: 28px;">👑</div>
          <div>
            <div style="font-size: 11px; font-weight: 800; color: #B45309; text-transform: uppercase;">VIP 尊榮長官抵達！</div>
            <div style="font-size: 16px; font-weight: 900; color: var(--text-charcoal); margin: 2px 0;">
              【${this.escapeHtml(guest.organization)}】${this.escapeHtml(guest.title)} ${this.escapeHtml(this.maskName(guest.name))}
            </div>
            <div style="font-size: 12px; color: var(--text-muted);">安排席位：<strong>${this.escapeHtml(guest.tableNo)}</strong> ‧ 請引導人員就位</div>
          </div>
        `;

        container.appendChild(toast);
        setTimeout(() => {
            toast.remove();
        }, 6000);
    }

    // =========================================================================
    // EXPORT & IMPORT
    // =========================================================================

    exportExcelRoster() {
        if (!this.currentEventId) {
            alert('⚠️ 目前尚無活動場次可供匯出名冊，請先點擊上方【➕ 建立新活動】！');
            return;
        }
        const url = window.apiService.getExportUrl(this.currentEventId);
        window.open(url, '_blank');
        this.showToast('報到名冊 Excel / CSV 匯出已開始下載', 'success');
    }

    showImportExcelModal() {
        if (!this.currentEventId) {
            alert('⚠️ 目前尚無活動場次可供匯入名冊，請先點擊上方【➕ 建立新活動】！');
            return;
        }
        const modal = document.getElementById('importExcelModal');
        if (modal) modal.classList.add('active');
        this.parsedExcelRows = [];
        const preview = document.getElementById('excelPreviewContainer');
        if (preview) preview.style.display = 'none';
        const confirmBtn = document.getElementById('confirmImportExcelBtn');
        if (confirmBtn) confirmBtn.style.display = 'none';
    }

    closeImportExcelModal() {
        const modal = document.getElementById('importExcelModal');
        if (modal) modal.classList.remove('active');
    }

    handleExcelFileSelect(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const data = new Uint8Array(e.target.result);
                const workbook = XLSX.read(data, { type: 'array' });
                const firstSheetName = workbook.SheetNames[0];
                const worksheet = workbook.Sheets[firstSheetName];
                const rows = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

                this.processParsedExcelRows(rows, file.name);
            } catch (err) {
                alert('解析 Excel 檔案失敗，請確認檔案格式是否為標準 .xlsx / .xls / .csv');
            }
        };
        reader.readAsArrayBuffer(file);
    }

    processParsedExcelRows(rows, filename) {
        if (!rows || rows.length < 2) {
            alert('檔案無資料或僅有標題列！');
            return;
        }

        const headers = rows[0].map(h => String(h || '').trim());
        const idCol = headers.findIndex(h => /卡號|工號|編號|id/i.test(h));
        const nameCol = headers.findIndex(h => /姓名|名字|name/i.test(h));
        const orgCol = headers.findIndex(h => /單位|部門|機構|服務單位|organization/i.test(h));
        const titleCol = headers.findIndex(h => /職稱|頭銜|title/i.test(h));
        const tableCol = headers.findIndex(h => /桌號|組別|席位|桌次|table/i.test(h));
        const phoneCol = headers.findIndex(h => /電話|手機|聯絡人|phone/i.test(h));

        this.parsedExcelRows = [];
        const tbody = document.getElementById('excelPreviewTbody');
        if (tbody) tbody.innerHTML = '';

        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            if (!row || row.length === 0) continue;

            const name = nameCol !== -1 ? String(row[nameCol] || '').trim() : String(row[0] || '').trim();
            if (!name) continue;

            const rawId = idCol !== -1 ? String(row[idCol] || '').trim() : '';
            const org = orgCol !== -1 ? String(row[orgCol] || '').trim() : '受邀單位';
            const title = titleCol !== -1 ? String(row[titleCol] || '').trim() : '貴賓';
            const table = tableCol !== -1 ? String(row[tableCol] || '').trim() : '未排桌';
            const phone = phoneCol !== -1 ? String(row[phoneCol] || '').trim() : '';

            let rankWeight = 3;
            if (/院長|局長|部長|署長|董事長|總裁/.test(title)) rankWeight = 1;
            else if (/副院長|議員|立委|代表|組長|督導|照專/.test(title)) rankWeight = 2;
            else if (/主任|教授|醫師|處長|學者|專家|講師/.test(title)) rankWeight = 3;
            else rankWeight = 4;

            const guestObj = {
                guestId: rawId || `G-${String(this.guests.length + i).padStart(3, '0')}`,
                name,
                organization: org,
                title,
                tableNo: table,
                phone,
                rankWeight,
                isCheckedIn: false
            };

            this.parsedExcelRows.push(guestObj);

            if (tbody) {
                tbody.innerHTML += `
                  <tr>
                    <td style="padding: 6px 10px;">${this.escapeHtml(guestObj.guestId)}</td>
                    <td style="padding: 6px 10px;">${this.escapeHtml(rawId || '-')}</td>
                    <td style="padding: 6px 10px;">${this.escapeHtml(org)}</td>
                    <td style="padding: 6px 10px;">${this.escapeHtml(title)}</td>
                    <td style="padding: 6px 10px; font-weight: 700;">${this.escapeHtml(name)}</td>
                    <td style="padding: 6px 10px;">${this.escapeHtml(table)}</td>
                    <td style="padding: 6px 10px;">${this.escapeHtml(phone)}</td>
                    <td style="padding: 6px 10px;">等級 ${rankWeight}</td>
                  </tr>
                `;
            }
        }

        const statusText = document.getElementById('importFileStatusText');
        if (statusText) statusText.innerText = `已辨識 ${filename}，共 ${this.parsedExcelRows.length} 位貴賓`;

        const preview = document.getElementById('excelPreviewContainer');
        if (preview) preview.style.display = 'block';

        const confirmBtn = document.getElementById('confirmImportExcelBtn');
        if (confirmBtn) confirmBtn.style.display = 'inline-block';
    }

    async executeImportExcel() {
        if (!this.parsedExcelRows || this.parsedExcelRows.length === 0) return;

        try {
            const res = await window.apiService.batchAddGuests(this.currentEventId, this.parsedExcelRows);
            this.showToast(`🚀 成功匯入 ${res.count || this.parsedExcelRows.length} 位貴賓名單！`, 'success');
            this.closeImportExcelModal();
            await this.loadGuestsAndStats();
        } catch (err) {
            alert(err.message || '匯入失敗');
        }
    }

    downloadExcelTemplate() {
        const sampleData = [
            ['員工卡號', '服務單位', '職稱', '姓名', '桌次組別', '電話', '備註'],
            ['00601441', '衛生福利部', '部長', '邱部長', 'VIP-1 主桌', '0912-345-678', '特邀致詞貴賓'],
            ['00601442', '秀傳紀念醫院', '院長', '黃院長', 'VIP-1 主桌', '0922-111-222', '大會主席'],
            ['00601443', '彰化縣衛生局', '局長', '李局長', 'VIP-1 主桌', '0933-555-777', '專案指導長官'],
            ['00601444', '彰濱秀傳紀念醫院', '副院長', '張副院長', 'VIP-2 貴賓席', '0988-999-000', '座談引言人'],
            ['00601445', '心血管醫學部', '主任', '陳主任', '第 3 組 (12桌)', '0955-667-788', '專題講師'],
            ['00601446', '資訊科技處', '工程師', '王同仁', '第 5 組 (15桌)', '0966-778-899', '同仁']
        ];

        const ws = XLSX.utils.aoa_to_sheet(sampleData);
        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, '貴賓名單範本');
        XLSX.writeFile(wb, 'InPoint_活動貴賓名單標準範本.xlsx');
    }

    // =========================================================================
    // MODALS & HELPERS
    // =========================================================================

    showAddGuestModal() {
        const modal = document.getElementById('addGuestModal');
        if (modal) modal.classList.add('active');
    }

    closeAddGuestModal() {
        const modal = document.getElementById('addGuestModal');
        if (modal) modal.classList.remove('active');
        const form = document.getElementById('addGuestForm');
        if (form) form.reset();
    }

    async handleAddNewGuest() {
        const name = document.getElementById('addGuestName')?.value.trim();
        const org = document.getElementById('addGuestOrg')?.value.trim();
        const title = document.getElementById('addGuestTitle')?.value.trim();
        const guestId = document.getElementById('addGuestId')?.value.trim();
        const tableNo = document.getElementById('addGuestTableNo')?.value.trim();
        const phone = document.getElementById('addGuestPhone')?.value.trim();
        const notes = document.getElementById('addGuestNotes')?.value.trim();

        if (!name) {
            alert('請輸入貴賓姓名！');
            return;
        }

        let rankWeight = 3;
        if (/院長|局長|部長|署長|董事長|總裁/.test(title || '')) rankWeight = 1;
        else if (/副院長|議員|立委|代表|組長|督導|照專/.test(title || '')) rankWeight = 2;
        else if (/主任|教授|醫師|處長|學者|專家|講師/.test(title || '')) rankWeight = 3;
        else rankWeight = 4;

        try {
            await window.apiService.addGuest(this.currentEventId, {
                guestId: guestId || undefined,
                name,
                organization: org || '受邀單位',
                title: title || '貴賓',
                tableNo: tableNo || '未排桌',
                phone,
                notes,
                rankWeight,
                isCheckedIn: false
            });

            this.showToast(`貴賓「${name}」已新增！`, 'success');
            this.closeAddGuestModal();
            await this.loadGuestsAndStats();
        } catch (err) {
            alert(err.message || '新增貴賓失敗');
        }
    }

    showDeleteGuestModal(guestId, guestName) {
        this.pendingDeleteGuestId = guestId;
        const desc = document.getElementById('deleteGuestConfirmDesc');
        if (desc) desc.innerText = `確定要刪除「${guestName}」(${guestId}) 嗎？此操作無法復原。`;
        const modal = document.getElementById('deleteGuestConfirmModal');
        if (modal) modal.classList.add('active');
    }

    closeDeleteGuestModal() {
        const modal = document.getElementById('deleteGuestConfirmModal');
        if (modal) modal.classList.remove('active');
        this.pendingDeleteGuestId = null;
    }

    async executeDeleteGuest() {
        if (!this.pendingDeleteGuestId) return;
        try {
            await window.apiService.deleteGuest(this.currentEventId, this.pendingDeleteGuestId);
            this.showToast('貴賓已刪除', 'success');
            this.closeDeleteGuestModal();
            await this.loadGuestsAndStats();
        } catch (err) {
            alert(err.message || '刪除失敗');
        }
    }

    showQrModal(guestId) {
        const guest = this.guests.find(g => g.guestId === guestId);
        if (!guest) return;

        const title = document.getElementById('qrModalGuestTitle');
        const desc = document.getElementById('qrModalGuestDesc');
        const qrContainer = document.getElementById('qrCodeSvgContainer');

        if (title) title.innerText = `【${this.maskName(guest.name)}】專屬報到 QR`;
        if (desc) desc.innerText = `編號：${guest.guestId} ‧ 桌次：${guest.tableNo}`;

        if (qrContainer && window.QRCode) {
            qrContainer.innerHTML = '';
            new window.QRCode(qrContainer, {
                text: guest.qrCodeHash || guest.guestId,
                width: 200,
                height: 200,
                colorDark: '#1A5E42',
                colorLight: '#FFFFFF'
            });
        }

        const modal = document.getElementById('qrPreviewModal');
        if (modal) modal.classList.add('active');
    }

    closeQrModal() {
        const modal = document.getElementById('qrPreviewModal');
        if (modal) modal.classList.remove('active');
    }

    // Scanner
    openScannerModal() {
        const modal = document.getElementById('qrScannerModal');
        if (modal) modal.classList.add('active');
        this.startCamera();
    }

    closeScannerModal() {
        const modal = document.getElementById('qrScannerModal');
        if (modal) modal.classList.remove('active');
        this.stopCamera();
    }

    async startCamera() {
        const video = document.getElementById('scannerVideo');
        if (!video) return;

        try {
            this.videoStream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'environment' }
            });
            video.srcObject = this.videoStream;
            video.setAttribute('playsinline', true);
            video.play();
        } catch (err) {
            console.warn('Camera access error:', err);
        }
    }

    stopCamera() {
        if (this.videoStream) {
            this.videoStream.getTracks().forEach(track => track.stop());
            this.videoStream = null;
        }
    }

    simulateQuickScan() {
        const pending = this.guests.find(g => !g.isCheckedIn);
        if (pending) {
            this.toggleCheckIn(pending.guestId, true);
            this.closeScannerModal();
            this.showToast(`📸 模擬掃描成功：【${this.maskName(pending.name)}】已完成報到！`, 'success');
        } else {
            alert('名單中已無未報到之貴賓！');
        }
    }

    // AI Assistant
    setAiPrompt(prompt) {
        const input = document.getElementById('aiQueryInput');
        if (input) {
            input.value = prompt;
            this.sendAiQuery();
        }
    }

    async sendAiQuery() {
        const input = document.getElementById('aiQueryInput');
        const box = document.getElementById('aiResponseBox');
        if (!input || !box) return;

        const query = input.value.trim();
        if (!query) return;

        box.innerHTML = `
          <div class="ai-response-header">
            <span>🤖</span> InPoint AI 會務助理思考中...
          </div>
          <div style="color: #64748B; font-size: 13.5px;">
            ⏳ 正在即時盤點現場貴賓到場數據、計算出席率並組織回答，請稍候...
          </div>
        `;

        try {
            const res = await window.apiService.queryAiAssistant(this.currentEventId, query);
            const reply = res.reply || '查詢無回應';
            box.innerHTML = `
              <div class="ai-response-header">
                <span>🤖</span> AI 會務秘書回覆：
              </div>
              <div style="color: #1E293B; font-size: 14px; line-height: 1.8; white-space: pre-wrap;">${this.escapeHtml(reply)}</div>
            `;
        } catch (err) {
            box.innerHTML = `
              <div class="ai-response-header" style="color: #DC2626;">
                <span>⚠️</span> 查詢異常：
              </div>
              <div style="color: #DC2626; font-size: 13.5px;">${this.escapeHtml(err.message)}</div>
            `;
        }
    }

    async parseAiRawText() {
        const textarea = document.getElementById('aiRawTextarea');
        if (!textarea) return;

        const raw = textarea.value.trim();
        if (!raw) {
            alert('請貼上名單文字！');
            return;
        }

        try {
            const res = await window.apiService.parseAiGuests(this.currentEventId, raw);
            if (res.parsedGuests && res.parsedGuests.length > 0) {
                await window.apiService.batchAddGuests(this.currentEventId, res.parsedGuests);
                this.showToast(`🚀 AI 智慧解析成功，已匯入 ${res.count} 位貴賓名單！`, 'success');
                textarea.value = '';
                await this.loadGuestsAndStats();
            }
        } catch (err) {
            alert(err.message || 'AI 解析失敗');
        }
    }

    switchTab(tabName) {
        this.currentTab = tabName;
        document.querySelectorAll('.nav-tab-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tab === tabName);
        });

        document.querySelectorAll('.tab-view').forEach(view => {
            view.classList.remove('active');
        });

        const targetView = document.getElementById(`${tabName}View`);
        if (targetView) {
            targetView.classList.add('active');
        }

        if (tabName === 'host') {
            this.renderHostView();
        } else if (tabName === 'staff') {
            this.renderStaffGuests();
        } else if (tabName === 'members') {
            this.loadMembers();
        } else if (tabName === 'admin') {
            this.renderAdminSpecs();
        }
    }

    togglePasswordVisibility(inputId, btn) {
        const inp = document.getElementById(inputId);
        if (inp) {
            if (inp.type === 'password') {
                inp.type = 'text';
                if (btn) btn.innerText = '🙈';
            } else {
                inp.type = 'password';
                if (btn) btn.innerText = '👁️';
            }
        }
    }

    showToast(message, type = 'info') {
        const container = document.getElementById('appToastContainer');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = `app-toast toast-${type}`;
        toast.innerText = message;
        container.appendChild(toast);

        setTimeout(() => {
            toast.classList.add('fade-out');
            setTimeout(() => toast.remove(), 300);
        }, 3500);
    }

    escapeHtml(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }
}

// Global Kiosk Launcher
window.openKioskScreen = function () {
    const eventId = window.app ? window.app.currentEventId : '';
    if (!eventId) {
        alert('⚠️ 目前尚無可投影之活動場次，請先點擊上方【➕ 建立新活動】！');
        return;
    }
    const token = window.apiService ? window.apiService.token : '';
    let url = 'kiosk.html';
    const params = new URLSearchParams();
    params.set('eventId', eventId);
    if (token) params.set('token', token);
    url += '?' + params.toString();
    window.open(url, '_blank');
};

// Global Create Event Launcher
window.showCreateEventModal = function () {
    if (window.app) window.app.showCreateEventModal();
};

document.addEventListener('DOMContentLoaded', () => {
    window.app = new CheckInApp();
});
