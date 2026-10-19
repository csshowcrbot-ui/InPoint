-- =============================================================================
-- InPoint: Zeabur PostgreSQL 遷移至 Railway PostgreSQL 資料匯入腳本
-- 導出時間 (UTC): 2026-10-19T22:03:47.6073421Z
-- 特點: 自動建表 (CREATE TABLE IF NOT EXISTS) 與冪等插入 (ON CONFLICT DO UPDATE)
-- =============================================================================

BEGIN;

-- -------------------------------------------------------------
-- 0. 自動建立資料表結構 (DDL，若不存在則建立)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "checkInUsers" (
    "UserId" VARCHAR(100) NOT NULL PRIMARY KEY,
    "Username" VARCHAR(100) NOT NULL,
    "PasswordHash" VARCHAR(255) NOT NULL,
    "Role" VARCHAR(50) NOT NULL,
    "DisplayName" VARCHAR(100) NULL,
    "Organization" VARCHAR(200) NULL,
    "PlanType" VARCHAR(50) NULL,
    "ExpireAt" TIMESTAMP NULL,
    "MaxGuestsPerEvent" INT NOT NULL DEFAULT 100,
    "MaxEvents" INT NOT NULL DEFAULT 1,
    "IsActive" BOOLEAN NOT NULL DEFAULT TRUE,
    "CreatedAt" TIMESTAMP NOT NULL DEFAULT NOW(),
    "Notes" VARCHAR(1000) NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS "IX_checkInUsers_Username" ON "checkInUsers" ("Username");

CREATE TABLE IF NOT EXISTS "checkInEvents" (
    "EventId" VARCHAR(100) NOT NULL PRIMARY KEY,
    "EventName" VARCHAR(255) NOT NULL,
    "EventDate" TIMESTAMP NOT NULL,
    "Location" VARCHAR(255) NULL,
    "Description" VARCHAR(1000) NULL,
    "IsActive" BOOLEAN NOT NULL DEFAULT TRUE,
    "CreatedAt" TIMESTAMP NOT NULL DEFAULT NOW(),
    "OwnerUsername" VARCHAR(100) NULL,
    "RankRules" TEXT NULL
);

CREATE TABLE IF NOT EXISTS "checkInGuests" (
    "EventId" VARCHAR(100) NOT NULL,
    "GuestId" VARCHAR(100) NOT NULL,
    "Name" VARCHAR(100) NOT NULL,
    "Organization" VARCHAR(200) NULL,
    "Title" VARCHAR(100) NULL,
    "RankWeight" INT NOT NULL DEFAULT 3,
    "TableNo" VARCHAR(50) NULL,
    "IsCheckedIn" BOOLEAN NOT NULL DEFAULT FALSE,
    "CheckedInAt" TIMESTAMP NULL,
    "CheckedInBy" VARCHAR(100) NULL,
    "QrCodeHash" VARCHAR(100) NULL,
    "Phone" VARCHAR(50) NULL,
    "Notes" VARCHAR(1000) NULL,
    PRIMARY KEY ("EventId", "GuestId")
);
CREATE INDEX IF NOT EXISTS "IX_checkInGuests_EventId" ON "checkInGuests" ("EventId");
CREATE INDEX IF NOT EXISTS "IX_checkInGuests_QrCodeHash" ON "checkInGuests" ("QrCodeHash");


-- -------------------------------------------------------------
-- 1. checkInUsers (會員與管理者帳號)
-- -------------------------------------------------------------
INSERT INTO "checkInUsers" ("UserId", "Username", "PasswordHash", "Role", "DisplayName", "Organization", "PlanType", "ExpireAt", "MaxGuestsPerEvent", "MaxEvents", "IsActive", "CreatedAt", "Notes")
VALUES ('user_admin', 'admin', '67d7c76ec280de73862cf46031851a1b8348e403c58b0dc0139732dca57d59ec', 'Admin', '系統最高管理員', 'InPoint 核心管理中心', 'Unlimited', NULL, 99999, -1, TRUE, '2026-10-10T14:02:30.144724Z'::timestamp, '預設系統管理員')
ON CONFLICT ("UserId") DO UPDATE SET
    "Username" = EXCLUDED."Username",
    "PasswordHash" = EXCLUDED."PasswordHash",
    "Role" = EXCLUDED."Role",
    "DisplayName" = EXCLUDED."DisplayName",
    "Organization" = EXCLUDED."Organization",
    "PlanType" = EXCLUDED."PlanType",
    "ExpireAt" = EXCLUDED."ExpireAt",
    "MaxGuestsPerEvent" = EXCLUDED."MaxGuestsPerEvent",
    "MaxEvents" = EXCLUDED."MaxEvents",
    "IsActive" = EXCLUDED."IsActive",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInUsers" ("UserId", "Username", "PasswordHash", "Role", "DisplayName", "Organization", "PlanType", "ExpireAt", "MaxGuestsPerEvent", "MaxEvents", "IsActive", "CreatedAt", "Notes")
VALUES ('user_annual_demo', 'annual_demo', '962658a01f95cfef96b45882a07061c389bb9b5f692b8994393e36e94dae44e9', 'Member', '年度專案', 'annual_demo', 'AnnualOrg', '2027-10-10T00:00:00Z'::timestamp, 1500, -1, TRUE, '2026-10-10T14:02:30.234674Z'::timestamp, '機構年度方案完整功能帳號')
ON CONFLICT ("UserId") DO UPDATE SET
    "Username" = EXCLUDED."Username",
    "PasswordHash" = EXCLUDED."PasswordHash",
    "Role" = EXCLUDED."Role",
    "DisplayName" = EXCLUDED."DisplayName",
    "Organization" = EXCLUDED."Organization",
    "PlanType" = EXCLUDED."PlanType",
    "ExpireAt" = EXCLUDED."ExpireAt",
    "MaxGuestsPerEvent" = EXCLUDED."MaxGuestsPerEvent",
    "MaxEvents" = EXCLUDED."MaxEvents",
    "IsActive" = EXCLUDED."IsActive",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInUsers" ("UserId", "Username", "PasswordHash", "Role", "DisplayName", "Organization", "PlanType", "ExpireAt", "MaxGuestsPerEvent", "MaxEvents", "IsActive", "CreatedAt", "Notes")
VALUES ('user_1b53dc117fba', 'demo_pei', '962658a01f95cfef96b45882a07061c389bb9b5f692b8994393e36e94dae44e9', 'Member', 'demo_pei', 'demo_pei', 'SingleEvent_Light', '2026-10-24T00:00:00Z'::timestamp, 100, 1, TRUE, '2026-10-13T08:50:21.883415Z'::timestamp, '小型研習/主管會報授權 (輕量級)')
ON CONFLICT ("UserId") DO UPDATE SET
    "Username" = EXCLUDED."Username",
    "PasswordHash" = EXCLUDED."PasswordHash",
    "Role" = EXCLUDED."Role",
    "DisplayName" = EXCLUDED."DisplayName",
    "Organization" = EXCLUDED."Organization",
    "PlanType" = EXCLUDED."PlanType",
    "ExpireAt" = EXCLUDED."ExpireAt",
    "MaxGuestsPerEvent" = EXCLUDED."MaxGuestsPerEvent",
    "MaxEvents" = EXCLUDED."MaxEvents",
    "IsActive" = EXCLUDED."IsActive",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInUsers" ("UserId", "Username", "PasswordHash", "Role", "DisplayName", "Organization", "PlanType", "ExpireAt", "MaxGuestsPerEvent", "MaxEvents", "IsActive", "CreatedAt", "Notes")
VALUES ('user_019354b57074', 'demo_01', '962658a01f95cfef96b45882a07061c389bb9b5f692b8994393e36e94dae44e9', 'Member', 'Demo_01', 'Demo_01', 'SingleEvent_Flagship', '2026-10-18T00:00:00Z'::timestamp, 500, 1, FALSE, '2026-10-10T22:23:26.301836Z'::timestamp, '打造永續共好地方創生計劃')
ON CONFLICT ("UserId") DO UPDATE SET
    "Username" = EXCLUDED."Username",
    "PasswordHash" = EXCLUDED."PasswordHash",
    "Role" = EXCLUDED."Role",
    "DisplayName" = EXCLUDED."DisplayName",
    "Organization" = EXCLUDED."Organization",
    "PlanType" = EXCLUDED."PlanType",
    "ExpireAt" = EXCLUDED."ExpireAt",
    "MaxGuestsPerEvent" = EXCLUDED."MaxGuestsPerEvent",
    "MaxEvents" = EXCLUDED."MaxEvents",
    "IsActive" = EXCLUDED."IsActive",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInUsers" ("UserId", "Username", "PasswordHash", "Role", "DisplayName", "Organization", "PlanType", "ExpireAt", "MaxGuestsPerEvent", "MaxEvents", "IsActive", "CreatedAt", "Notes")
VALUES ('user_single_demo', 'single_demo', '962658a01f95cfef96b45882a07061c389bb9b5f692b8994393e36e94dae44e9', 'Member', '單場活動試用', 'Single_demo', 'SingleEvent', '2026-10-17T00:00:00Z'::timestamp, 500, 1, FALSE, '2026-10-10T14:02:30.230934Z'::timestamp, '單場活動 7 天授權體驗帳號')
ON CONFLICT ("UserId") DO UPDATE SET
    "Username" = EXCLUDED."Username",
    "PasswordHash" = EXCLUDED."PasswordHash",
    "Role" = EXCLUDED."Role",
    "DisplayName" = EXCLUDED."DisplayName",
    "Organization" = EXCLUDED."Organization",
    "PlanType" = EXCLUDED."PlanType",
    "ExpireAt" = EXCLUDED."ExpireAt",
    "MaxGuestsPerEvent" = EXCLUDED."MaxGuestsPerEvent",
    "MaxEvents" = EXCLUDED."MaxEvents",
    "IsActive" = EXCLUDED."IsActive",
    "Notes" = EXCLUDED."Notes";

-- -------------------------------------------------------------
-- 2. checkInEvents (活動場次)
-- -------------------------------------------------------------
INSERT INTO "checkInEvents" ("EventId", "EventName", "EventDate", "Location", "Description", "IsActive", "CreatedAt", "OwnerUsername", "RankRules")
VALUES ('event_20261011_003236_a812ce', 'DEMO', '2026-10-11T00:32:00Z'::timestamp, 'DEMO', '', TRUE, '2026-10-11T00:32:36.489879Z'::timestamp, 'annual_demo', '{"rank1Keywords":["院長","局長","部長","署長","董事長","總裁","副部長","校長","理事長","市長","縣長"],"rank2Keywords":["副院長","副局長","議員","立委","代表","組長","科長","副署長","委員","督導","副市長","副縣長","秘書長"],"rank3Keywords":["主任","教授","醫師","處長","顧問","隊長","副主任","總監","學者","專家","講師","經理","協理"],"rank4Keywords":["照專"]}')
ON CONFLICT ("EventId") DO UPDATE SET
    "EventName" = EXCLUDED."EventName",
    "EventDate" = EXCLUDED."EventDate",
    "Location" = EXCLUDED."Location",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "OwnerUsername" = EXCLUDED."OwnerUsername",
    "RankRules" = EXCLUDED."RankRules";
INSERT INTO "checkInEvents" ("EventId", "EventName", "EventDate", "Location", "Description", "IsActive", "CreatedAt", "OwnerUsername", "RankRules")
VALUES ('event_20261010_222428_1570fd', '打造永續共好地方創生計劃', '2026-10-15T16:30:00Z'::timestamp, '地方創生', '', TRUE, '2026-10-10T22:24:28.198348Z'::timestamp, 'demo_01', '{"rank1Keywords":["院長","局長","部長","署長","董事長","總裁","副部長","校長","理事長","市長","縣長"],"rank2Keywords":["副院長","副局長","議員","立委","代表","組長","科長","副署長","委員","督導","副市長","副縣長","秘書長"],"rank3Keywords":["主任","教授","醫師","處長","顧問","隊長","副主任","總監","學者","專家","講師","經理","協理"],"rank4Keywords":["照專"]}')
ON CONFLICT ("EventId") DO UPDATE SET
    "EventName" = EXCLUDED."EventName",
    "EventDate" = EXCLUDED."EventDate",
    "Location" = EXCLUDED."Location",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "OwnerUsername" = EXCLUDED."OwnerUsername",
    "RankRules" = EXCLUDED."RankRules";
INSERT INTO "checkInEvents" ("EventId", "EventName", "EventDate", "Location", "Description", "IsActive", "CreatedAt", "OwnerUsername", "RankRules")
VALUES ('event_20261015_061409_6b980b', '醫療法規實務解析、案例分享及醫療爭議調解現況', '2026-10-22T04:30:00Z'::timestamp, '苑裡李綜合醫院10樓視聽中心', '講師：苗栗縣政府衛生局張章裕科長
對象：體系全體同仁，均請踴躍參加

大綱：
1.衛政與長照組織架構
2.醫療法規實務解析(含醫預法)
3.人民陳情案處辦探討
4.交流討論

會申請醫事人員繼續教育積分：護理/藥放檢/營養/社工/專師/醫師/復健(3T)', TRUE, '2026-10-15T06:14:09.797737Z'::timestamp, 'demo_pei', NULL)
ON CONFLICT ("EventId") DO UPDATE SET
    "EventName" = EXCLUDED."EventName",
    "EventDate" = EXCLUDED."EventDate",
    "Location" = EXCLUDED."Location",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "OwnerUsername" = EXCLUDED."OwnerUsername",
    "RankRules" = EXCLUDED."RankRules";
INSERT INTO "checkInEvents" ("EventId", "EventName", "EventDate", "Location", "Description", "IsActive", "CreatedAt", "OwnerUsername", "RankRules")
VALUES ('event_20261020_055937_53ed8a', 'demo_1020', '2026-10-19T21:59:00Z'::timestamp, 'demo', 'demo', TRUE, '2026-10-19T21:59:37.157499Z'::timestamp, 'annual_demo', NULL)
ON CONFLICT ("EventId") DO UPDATE SET
    "EventName" = EXCLUDED."EventName",
    "EventDate" = EXCLUDED."EventDate",
    "Location" = EXCLUDED."Location",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "OwnerUsername" = EXCLUDED."OwnerUsername",
    "RankRules" = EXCLUDED."RankRules";

-- -------------------------------------------------------------
-- 3. checkInGuests (貴賓與名冊，共 164 筆)
-- -------------------------------------------------------------
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '14', '林秀虹', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261010_222428_1570fd-14', '0911704533', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '17', '林欣怡', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261010_222428_1570fd-17', '0921684350', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '40', '陳琦諺', '花蓮縣秀林鄉衛生所', '其他', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261010_222428_1570fd-40', '0911374540', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '41', '倪頌惠', '社團法人中華民國士林靈糧堂社會福利協會', '日照機構代表', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261010_222428_1570fd-41', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '32', '冉舜文', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:07:35.302611Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-32', '0965348373', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '4', '羅芮靚', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T01:01:46.640421Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-4', '0977276213', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '36', '謝佩倫', '新城鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:42:42.088189Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-36', '0955769020', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '27', '莊心薇', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:08:48.133029Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-27', '0921863639', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '12', '李姝蓉', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:19:50.235313Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-12', '0963695112', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '30', '蔡惟欣', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:25:37.157258Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-30', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '34', '潘鎮鈺', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:07:28.988575Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-34', '0911006196', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '25', '張淑媚', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-12T00:36:54.184811Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-25', '0911368627', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '28', '陳錦秋', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:11:25.769014Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-28', '0919942052', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '29', '張雅婷', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:11:53.457787Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-29', '03-8230232', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '37', '林莉雯', '壽豐鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:19:53.523823Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-37', '0930060543', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '2', '謝蓉蓉', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T00:23:10.265332Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-2', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '23', '沈懿嬅', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:28:42.23104Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-23', '0963203931', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '22', '呂家渝', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:31:07.78856Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-22', '03-8230232', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '26', '高莉萍', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:31:15.178619Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-26', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '24', '劉純真', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:31:16.421037Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-24', '03-8226889', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '35', '潘淑琴', '新城鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:31:17.121289Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-35', '0955769020', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '33', '朱若慈', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:32:23.408171Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-33', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '11', '楊佩林', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:34:45.189298Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-11', '0911338700', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '18', '汪盈君', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:35:10.146206Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-18', '0952550702', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '15', '劉育如', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:36:50.0864Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-15', '0919964962', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '13', '陳依琳', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:39:27.234301Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-13', '0933829413', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '20', '羅思庭', '秀林鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:41:42.151178Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-20', '0905621243', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '3', '黃翊珊', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T00:42:14.272708Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-3', '0933051918', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '38', '游家偉', '壽豐鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:42:44.05283Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-38', '0938601006', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '31', '方婷', '花蓮市衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:43:09.91254Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-31', '0900620982', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '21', '簡紫薇', '秀林鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:43:11.873155Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-21', '0928074110', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '19', '張偉恩', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:43:14.742632Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-19', '0919188508', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '16', '葉士瑜', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:43:17.117198Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-16', '0988456654', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '10', '張佩慈', '吉安鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:43:32.697195Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-10', '0925025641', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '39', '張芷茹', '壽豐鄉衛生所長照分站', '照專', 4, '未排桌', TRUE, '2026-10-16T00:48:09.390374Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-39', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '1', '戴玉琴', '有限責任臺灣第二照顧服務勞動合作社／執行長', '講師', 3, '未排桌', TRUE, '2026-10-16T00:54:15.146029Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-1', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '10', '黃宇軒', '花蓮縣衛生所長照分站', '照專督導', 2, '未排桌', TRUE, '2026-10-14T01:31:53.182093Z'::timestamp, '年度專案 (工作台)', 'SC-20261011_003236_a812ce-10', '0975563751', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '53', '吳允熙', '門諾醫院長照部(A單位)', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:43:00.775838Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-53', '0926007797', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '1', '蕭美惠', '壽豐鄉衛生所長照分站', '主任', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-1', '0972627979', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '100', '莊俊傑', '吉安鄉醫療財團法人醫院', '講師', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-100', '0977821282', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '14', '游宗憲', '玉里鎮衛生所長照分站', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-14', '0933939132', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '15', '鄭玉琴', '光復鄉衛生所長照分站', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-15', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '17', '高佩萱', '壽豐鄉衛生所長照分站', '物理治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-17', '0910240248', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '18', '戴承翰', '門諾醫院', '主任', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-18', '0975331104', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '19', '劉佩慈', '玉里鎮衛生所長照分站', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-19', '0925124937', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '20', '莊若涵', '新城鄉榮民醫院', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-20', '0933319072', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '21', '徐志明', '彰化基督教醫院', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-21', '0920556261', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '22', '黃佳穎', '瑞穗鄉衛生所長照分站', '營養師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-22', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '11', '游維君', '竹山鎮護理之家', '專案經理', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-11', '0977310618', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '16', '黃俊廷', '瑞穗鄉榮民醫院', '專案經理', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-16', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '45', '林宜靜', '士林靈糧堂吉安A單位', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:54:28.750884Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-45', '0905661627', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '2', '洪俊廷', '雲林縣日間照顧中心', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-2', '0911367640', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '9', '馬維君', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T06:02:16.442028Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-9', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '57', '程瑞芸', '國軍花蓮總醫院附設民眾診療服務處A單位', 'A個管', 4, '未排桌', TRUE, '2026-10-16T06:02:19.260735Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-57', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '46', '陳李玟', '佛教慈濟醫療財團法人花蓮慈濟醫院', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:40:46.410577Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-46', '0981309673', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '12', '楊志明', '玉里鎮衛生所長照分站', '照專督導', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-12', '0911162472', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '55', '蔡育嫻', '門諾醫院壽豐', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:27:19.749732Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-55', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '13', '張冠宇', '門諾醫院', '組長', 2, '未排桌', TRUE, '2026-10-14T01:31:59.097624Z'::timestamp, '年度專案 (工作台)', 'SC-20261011_003236_a812ce-13', '0988443487', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '44', '艾潔如', '財團法人門諾社會褔利慈事業基金會附設花蓮私立壽豐社區長照機構', '日照機構代表', 2, '未排桌', TRUE, '2026-10-16T00:23:33.890767Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-44', '0976071515', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '47', '楊青青', '秀林鄉衛生所長照A單位', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:31:14.059088Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-47', '0977336908', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '59', '劉瀚陽', '臺灣基督教門諾會醫療財團法人門諾醫院(吉安鄉A單位)', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:32:01.70572Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-59', '0988792935', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '43', '張芷盈', '財團法人門諾社會福利慈善事業基金會附設花蓮縣私立 花蓮綜合長照機構(日照中心)', '日照機構代表', 2, '未排桌', TRUE, '2026-10-16T00:32:19.592301Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-43', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '8', '陳美玲', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T00:33:59.822681Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-8', '0933480322', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '50', '王柔', '社團法人中華民國士林靈糧堂社會福利協會花蓮市A單位', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:41:58.175042Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-50', '0966976758', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '42', '王萱', '社團法人中華民國士林靈糧堂社會福利協會附設花蓮縣私立米崙社區式長照機構', '日照機構代表', 2, '未排桌', TRUE, '2026-10-16T00:42:26.702373Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-42', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '51', '黃育潔', '社團法人中華民國士林靈糧堂社會福利協會花蓮市A單位', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:43:26.172222Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-51', '0978085756', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '56', '梁顥繽', '國軍花蓮總醫院附設民眾診療服務處', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:45:30.866802Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-56', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '48', '周郁恩', '社團法人中華民國士林靈糧堂社會福利協會(吉安)', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:47:14.510535Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-48', '0919381282', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '58', '張凱翔', '臺灣基督教門諾會醫療財團法人門諾醫院(吉安鄉A單位)', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:49:32.107415Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-58', '0916339498', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '5', '鄭芝琪', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T00:53:19.381323Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-5', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '54', '蔡淑惠', '門諾醫院壽豐', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:55:12.025301Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-54', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '6', '白芮瑄', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T00:59:19.652911Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-6', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '23', '張思婷', '瑞穗鄉社區整合服務中心', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-23', '0920135326', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '24', '張玉琴', '竹山鎮社會福利慈善事業基金會', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-24', '0932799702', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '25', '張翊珊', '玉里鎮社區整合服務中心', '照顧服務員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-25', '0921733819', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '26', '葉廷宇', '竹山鎮護理之家', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-26', '0912592368', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '27', '蘇宗憲', '有限責任臺灣第二照顧服務勞動合作社', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-27', '0933200766', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '28', '高冠宇', '彰化縣照顧服務勞動合作社', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-28', '0910298474', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '29', '潘建宏', '宜蘭縣社會福利慈善事業基金會', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-29', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '3', '蕭凱婷', '臺北榮總玉里分院', '營養師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-3', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '30', '潘維君', '鳳林鎮社會福利慈善事業基金會', '主任', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-30', '0932235160', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '31', '方宇軒', '有限責任花蓮縣第一居家長照機構', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-31', '0937731752', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '32', '張美玲', '光復鄉護理之家', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-32', '0933164817', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '33', '江書豪', '鳳林鎮衛生所長照分站', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-33', '0977994710', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '34', '邱欣怡', '新城鄉日間照顧中心', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-34', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '35', '馬柏翰', '新城鄉衛生所長照分站', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-35', '0921894557', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '36', '黃建宏', '新城鄉居家護理所', '營養師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-36', '0921135110', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '37', '方凱婷', '秀傳紀念醫院', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-37', '0932747066', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '38', '徐芮瑄', '花蓮縣社區整合服務中心', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-38', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '39', '江翊珊', '有限責任花蓮縣第一居家長照機構', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-39', '0920102714', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '4', '白宗憲', '愛迪樂物理治療所', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-4', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '40', '吳雅婷', '國軍花蓮總醫院', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-40', '0972933845', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '41', '盧家豪', '康泰日間照顧中心', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-41', '0912894679', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '42', '郭冠廷', '南投縣衛生局', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-42', '0933149025', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '43', '陳柏翰', '仁愛居家護理所', '照顧服務員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-43', '0972491016', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '44', '邱維君', '門諾醫院', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-44', '0975167073', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '45', '吳佩萱', '永和日間照顧中心', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-45', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '46', '江佩林', '門諾醫院', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-46', '0933922306', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '47', '潘冠廷', '臺東縣基督教醫院', '物理治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-47', '0977281328', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '48', '陳佩林', '秀傳紀念醫院', '照專督導', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-48', '0975265998', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '49', '詹宇軒', '康泰日間照顧中心', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-49', '0972358532', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '5', '方俊廷', '吉安鄉衛生所長照分站', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-5', '0921513813', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '50', '謝維君', '仁愛居家護理所', '照專督導', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-50', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '51', '沈柏翰', '吉安鄉物理治療所', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-51', '0912247340', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '52', '張佩林', '臺北榮總鳳林分院', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-52', '0911697126', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '53', '周翊珊', '有限責任臺灣第二照顧服務勞動合作社', '講師', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-53', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '54', '羅佳穎', '彰化縣照顧服務勞動合作社', '照顧服務員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-54', '0920436088', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '55', '江淑芬', '竹山鎮居家護理所', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-55', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '56', '白佩林', '瑞穗鄉衛生所長照分站', '物理治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-56', '0912848514', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '57', '鄭俊傑', '竹山秀傳醫院', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-57', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '58', '王冠廷', '新城鄉照顧服務勞動合作社', '照專督導', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-58', '0977515643', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '59', '潘彥均', '弘道老人福利基金會', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-59', '0910844413', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '6', '羅玉琴', '花蓮縣衛生局', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-6', '0920661075', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '60', '鄭宗憲', '花蓮縣衛生局', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-60', '0933805008', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '61', '江凱婷', '玉里鎮社會福利慈善事業基金會', '講師', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-61', '0933310497', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '62', '莊雅婷', '玉里鎮衛生所長照分站', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-62', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '63', '徐家瑋', '彰化縣榮民醫院', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-63', '0928800673', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '64', '蘇柏翰', '有限責任花蓮縣第一居家長照機構', '照顧服務員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-64', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '65', '李芮靚', '秀傳紀念醫院', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-65', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '66', '洪雅婷', '鳳林鎮衛生所長照分站', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-66', '0920241815', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '67', '高芷萍', '光復鄉衛生所長照分站', '營養師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-67', '0912474009', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '69', '詹建宏', '光復鄉榮民醫院', '物理治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-69', '0910124796', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '7', '莊玉琴', '有限責任臺灣第二照顧服務勞動合作社', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-7', '0988260816', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '70', '葉佩林', '壽豐鄉衛生所長照分站', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-70', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '71', '楊美惠', '彰化基督教醫院', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-71', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '72', '陳家豪', '有限責任花蓮縣第一居家長照機構', '物理治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-72', '0928186502', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '73', '江雅玲', '吉安鄉衛生所長照分站', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-73', '0925861912', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '74', '徐書豪', '吉安鄉衛生所長照分站', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-74', '0975177597', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '75', '彭佩林', '有限責任臺灣第二照顧服務勞動合作社', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-75', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '77', '賴俊廷', '新城鄉衛生所長照分站', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-77', '0972265012', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '79', '張承翰', '弘道老人福利基金會', '照顧服務員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-79', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '8', '楊承翰', '光復鄉衛生所長照分站', '照專督導', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-8', '0975968351', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '80', '黃佩萱', '竹山秀傳醫院', '照顧服務員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-80', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '81', '楊品妤', '康泰日間照顧中心', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-81', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '82', '王芷萍', '宜蘭縣老人福利保護協會', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-82', '0928256399', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '83', '許俊傑', '彰化縣榮民醫院', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-83', '0933577816', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '84', '鄭冠宇', '老五老基金會', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-84', '0910646168', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '85', '葉佳穎', '玉里鎮日間照顧中心', '個管員', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-85', '0911150394', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '86', '柯家瑋', '彰化縣醫療財團法人醫院', '組長', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-86', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '87', '鄭芮靚', '新城鄉居家護理所', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-87', '0932289427', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '88', '黃美玲', '宜蘭縣衛生局', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-88', '0911247328', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '89', '賴芮靚', '雲林縣家庭照顧者關懷協會', '職能治療師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-89', '0977164081', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '9', '彭若涵', '竹山鎮社區整合服務中心', '照專', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-9', '0988289957', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '90', '廖美玲', '吉安鄉社區整合服務中心', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-90', '0925897575', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '92', '黃書豪', '康泰日間照顧中心', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-92', '0920305314', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '93', '柯佩萱', '南投縣衛生局', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-93', '0977581476', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '94', '邱冠廷', '光復鄉衛生所長照分站', '行政助理', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-94', '0937818928', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '95', '郭芷萍', '南投縣照顧服務勞動合作社', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-95', '0937651340', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '96', '葉俊傑', '新城鄉衛生所長照分站', '負責人', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-96', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '97', '洪品妤', '仁愛居家護理所', '社工師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-97', '0911362678', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '98', '蔡佩萱', '康泰日間照顧中心', '護理師', 4, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-98', '0937816890', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '99', '賴維君', '吉安鄉老人福利保護協會', '照專督導', 2, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-99', '0975104191', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '68', '羅淑芬', '新城鄉衛生所長照分站', '專案經理', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-68', '0925696963', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '76', '賴冠宇', '雲林縣老人福利保護協會', '專案經理', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-76', '0988988164', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '78', '廖翊珊', '彰化縣榮民醫院', '專案經理', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-78', '0975837899', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '91', '盧佳穎', '臺東縣社區整合服務中心', '專案經理', 3, '未排桌', FALSE, NULL, NULL, 'SC-20261011_003236_a812ce-91', '0912291184', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', 'G-061', '劉瑞華', '受邀單位', '貴賓', 4, '未排桌', TRUE, '2026-10-16T00:33:20.746212Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-G-061', '', '')
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', 'G-062', '陳靜蓉', '受邀單位', '貴賓', 4, '未排桌', TRUE, '2026-10-16T00:38:57.654178Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-G-062', '', '')
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '52', '潘佳欣', '門諾醫院長照部(A單位)', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:41:50.091049Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-52', '0905663700', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '49', '黃仁弘', '社團法人中華民國士林靈糧堂社會福利協會(吉安A單位)', 'A個管', 4, '未排桌', TRUE, '2026-10-16T00:43:52.087725Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-49', '0975000447', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', 'G-064', '潘佳鈴', '受邀單位', '貴賓', 4, '未排桌', TRUE, '2026-10-16T00:46:54.740105Z'::timestamp, '手機掃碼自主報到', 'SC-20261010_222428_1570fd-G-064', '', '')
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', '7', '張芷萍', '花蓮縣衛生局', '照專督導', 2, '未排桌', TRUE, '2026-10-16T01:02:13.873146Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-7', '', NULL)
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261010_222428_1570fd', 'G-060', '陳婉怡', '受邀單位', '貴賓', 4, '未排桌', TRUE, '2026-10-16T01:05:25.376079Z'::timestamp, 'Demo_01 (工作台)', 'SC-20261010_222428_1570fd-G-060', '', '')
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";
INSERT INTO "checkInGuests" ("EventId", "GuestId", "Name", "Organization", "Title", "RankWeight", "TableNo", "IsCheckedIn", "CheckedInAt", "CheckedInBy", "QrCodeHash", "Phone", "Notes")
VALUES ('event_20261011_003236_a812ce', '601441', '張凱程', '下班後', 'CEO', 4, 'VIP-1', TRUE, '2026-10-19T05:16:34.387535Z'::timestamp, '年度專案 (工作台)', 'SC-20261011_003236_a812ce-601441', '0919735729', '測試資料')
ON CONFLICT ("EventId", "GuestId") DO UPDATE SET
    "Name" = EXCLUDED."Name",
    "Organization" = EXCLUDED."Organization",
    "Title" = EXCLUDED."Title",
    "RankWeight" = EXCLUDED."RankWeight",
    "TableNo" = EXCLUDED."TableNo",
    "IsCheckedIn" = EXCLUDED."IsCheckedIn",
    "CheckedInAt" = EXCLUDED."CheckedInAt",
    "CheckedInBy" = EXCLUDED."CheckedInBy",
    "QrCodeHash" = EXCLUDED."QrCodeHash",
    "Phone" = EXCLUDED."Phone",
    "Notes" = EXCLUDED."Notes";

-- 清理初期測試假活動
DELETE FROM "checkInGuests" WHERE "EventId" = 'event_20260917_084526';
DELETE FROM "checkInEvents" WHERE "EventId" = 'event_20260917_084526';

COMMIT;
-- =============================================================================
-- 遷移 SQL 產生完成！共 5 位使用者、4 場活動 (含 demo_1020)、164 筆名冊
-- =============================================================================
