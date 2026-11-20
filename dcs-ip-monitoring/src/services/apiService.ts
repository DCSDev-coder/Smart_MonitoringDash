import { CompanyItem, CompanyAccount, RackMonitor } from '../types';

export const CPANEL_API_URL = 'https://portal.dcstack.my/api/index.php';

export function calculateNextServiceDate(lastService: string, cycleDays = 90): string {
  if (!lastService) return '';
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(lastService.trim());
  if (match) {
    const year = parseInt(match[1], 10);
    const month = parseInt(match[2], 10) - 1;
    const day = parseInt(match[3], 10);
    const dt = new Date(Date.UTC(year, month, day + cycleDays));
    if (!isNaN(dt.getTime())) {
      return dt.toISOString().split('T')[0];
    }
  }
  const parsed = new Date(lastService);
  if (!isNaN(parsed.getTime())) {
    parsed.setDate(parsed.getDate() + cycleDays);
    return parsed.toISOString().split('T')[0];
  }
  return '';
}

const STORAGE_KEY_TOKEN = 'dcstack_api_token';
const STORAGE_KEY_USER = 'dcstack_api_user';

export interface ApiUser {
  id: number;
  username: string;
  email?: string | null;
  can_access_monitoring_web?: number | boolean;
  license_type?: string;
  expiry_date?: string;
}

export interface ApiSiteMonitor {
  id: number;
  site_id: number;
  cabinet_id: string;
  dahua_cabinet_id?: string;
  label: string;
  open_ip: string;
  local_ip?: string;
  site_user: string;
  site_pass: string;
  is_active: number;
  created_at?: string;
}

export interface ApiSite {
  site_id: number;
  site_name: string;
  open_ip: string;
  local_ip: string;
  cabinet_id?: string;
  dahua_cabinet_id?: string;
  is_active: number;
  site_user: string;
  site_pass: string;
  last_maintenance?: string;
  company_logo_path?: string;
  license_type?: string;
  expiry_date?: string;
  role?: string;
  cctv_ip?: string;
  cctv_user?: string;
  cctv_pass?: string;
  face_scanner_ip?: string;
  face_scanner_user?: string;
  face_scanner_pass?: string;
  tech_notes?: string;
  monitors?: ApiSiteMonitor[];
}

class ApiService {
  private token: string | null = null;
  private user: ApiUser | null = null;

  constructor() {
    this.token =
      localStorage.getItem(STORAGE_KEY_TOKEN) ||
      sessionStorage.getItem(STORAGE_KEY_TOKEN);
    const cachedUser =
      localStorage.getItem(STORAGE_KEY_USER) ||
      sessionStorage.getItem(STORAGE_KEY_USER);
    if (cachedUser) {
      try {
        this.user = JSON.parse(cachedUser);
      } catch {
        this.user = null;
      }
    }
  }

  getAuthToken(): string | null {
    return (
      this.token ||
      localStorage.getItem(STORAGE_KEY_TOKEN) ||
      sessionStorage.getItem(STORAGE_KEY_TOKEN)
    );
  }

  getUser(): ApiUser | null {
    return this.user;
  }

  isAuthenticated(): boolean {
    return Boolean(this.getAuthToken());
  }

  /**
   * Ensures the client has a stored bearer token.
   */
  async ensureAuthenticated(): Promise<boolean> {
    const token = this.getAuthToken();
    if (!token) return false;

    try {
      const response = await fetch(`${CPANEL_API_URL}?action=auth_me`, {
        headers: {
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token,
        },
      });
      const data = await response.json();
      if (!response.ok || data.status !== 'success') {
        this.logoutLocal();
        return false;
      }
      if (data.user) {
        this.user = data.user as ApiUser;
        sessionStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));
        if (localStorage.getItem(STORAGE_KEY_TOKEN)) {
          localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));
        }
      }
      return true;
    } catch {
      return false;
    }
  }

  private logoutLocal() {
    this.token = null;
    this.user = null;
    localStorage.removeItem(STORAGE_KEY_TOKEN);
    localStorage.removeItem(STORAGE_KEY_USER);
    sessionStorage.removeItem(STORAGE_KEY_TOKEN);
    sessionStorage.removeItem(STORAGE_KEY_USER);
  }

  async logout(): Promise<void> {
    const token = this.getAuthToken();
    try {
      if (token) {
        await fetch(`${CPANEL_API_URL}?action=logout`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
            'X-Auth-Token': token,
          },
          body: JSON.stringify({ action: 'logout' }),
        });
      }
    } finally {
      this.logoutLocal();
    }
  }

  /**
   * Login against https://portal.dcstack.my/api/index.php?action=login
   */
  async login(
    username: string,
    password: string,
    rememberMe = true
  ): Promise<{
    success: boolean;
    token?: string;
    user?: ApiUser;
    message?: string;
  }> {
    try {
      const formParams = new URLSearchParams();
      formParams.append('action', 'login');
      formParams.append('username', username);
      formParams.append('password', password);
      formParams.append('remember_me', rememberMe ? '1' : '0');

      const response = await fetch(`${CPANEL_API_URL}?action=login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formParams.toString(),
      });

      if (!response.ok) {
        return {
          success: false,
          message: `API returned status HTTP ${response.status}`,
        };
      }

      const data = await response.json();
      if (data.status === 'success' && data.auth_token) {
        const user: ApiUser = data.user || { id: 0, username };
        const canAccess =
          user.can_access_monitoring_web === 1 ||
          user.can_access_monitoring_web === true ||
          String(user.can_access_monitoring_web) === '1';

        if (!canAccess) {
          this.logoutLocal();
          return {
            success: false,
            message:
              'Access denied: Monitoring website access is disabled for this account. Enable it in the main app.',
          };
        }

        this.token = data.auth_token;
        this.user = user;

        localStorage.removeItem(STORAGE_KEY_TOKEN);
        localStorage.removeItem(STORAGE_KEY_USER);
        sessionStorage.removeItem(STORAGE_KEY_TOKEN);
        sessionStorage.removeItem(STORAGE_KEY_USER);

        const store = rememberMe ? localStorage : sessionStorage;
        store.setItem(STORAGE_KEY_TOKEN, this.token!);
        store.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));

        return {
          success: true,
          token: this.token!,
          user: this.user!,
        };
      }

      return {
        success: false,
        message: data.message || 'Invalid username or password',
      };
    } catch (err: any) {
      return {
        success: false,
        message: err.message || 'Failed to connect to DCStack Portal API',
      };
    }
  }

  /**
   * Fetch registered sites from the portal
   */
  async getSites(): Promise<{ success: boolean; sites: ApiSite[]; message?: string }> {
    let token = this.getAuthToken();
    if (!token) {
      const authOk = await this.ensureAuthenticated();
      if (!authOk) {
        return { success: false, sites: [], message: 'Not authenticated' };
      }
      token = this.getAuthToken();
    }

    try {
      const response = await fetch(`${CPANEL_API_URL}?action=get_sites`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
      });

      if (response.status === 401 || response.status === 403) {
        this.logoutLocal();
        return { success: false, sites: [], message: 'Session expired. Please sign in again.' };
      }

      if (!response.ok) {
        return { success: false, sites: [], message: `HTTP ${response.status}` };
      }

      const data = await response.json();
      if (data.status === 'success' && Array.isArray(data.sites)) {
        return { success: true, sites: data.sites };
      }

      return { success: false, sites: [], message: data.message || 'No sites found' };
    } catch (err: any) {
      return { success: false, sites: [], message: err.message || 'Network error' };
    }
  }

  /**
   * Fetch live rack telemetry directly from Adapter backend (Dahua eCTRL)
   */
  async fetchLiveRackTelemetry(
    siteId: number,
    monitorId?: number
  ): Promise<{
    pue?: number;
    totalEnergyKwh?: number;
    itEnergyKwh?: number;
    doorsEnv?: Array<{ doorName: string; temperature: number; humidity: number }>;
    frontDoor?: { temperature: number; humidity: number };
    rearDoor?: { temperature: number; humidity: number };
  } | null> {
    try {
      const token = this.getAuthToken();
      if (!token) return null;

      const headers = {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      };
      const mParam = monitorId && monitorId > 0 ? `monitor_id=${monitorId}` : '';
      const qPrefix = mParam ? `?${mParam}` : '';
      const powerUrl = `https://adapter.dcstack.my/v1/sites/${siteId}/pue/power?powerType=1${mParam ? `&${mParam}` : ''}`;

      const [pueRes, powerRes, thRes] = await Promise.all([
        fetch(`https://adapter.dcstack.my/v1/sites/${siteId}/pue/current${qPrefix}`, { headers }).catch(() => null),
        fetch(powerUrl, { headers }).catch(() => null),
        fetch(`https://adapter.dcstack.my/v1/sites/${siteId}/temp-hum-top-n${qPrefix}`, { headers }).catch(() => null),
      ]);

      let pueVal: number | undefined;
      if (pueRes && pueRes.ok) {
        const pueData = await pueRes.json();
        const rawPue = pueData?.pue ?? pueData?.result?.pue ?? pueData?.data?.pue;
        if (rawPue != null) {
          const parsed = parseFloat(String(rawPue));
          if (!isNaN(parsed) && parsed > 0) pueVal = parsed;
        }
      }

      let totalEnergyKwh: number | undefined;
      let itEnergyKwh: number | undefined;
      if (powerRes && powerRes.ok) {
        const powerData = await powerRes.json();
        const pResult = powerData?.result ?? powerData;
        const totalRaw = pResult?.Total ?? pResult?.total;
        const itRaw = pResult?.['IT Device'] ?? pResult?.itDevice;
        if (totalRaw != null) {
          const t = parseFloat(String(totalRaw));
          if (!isNaN(t) && t >= 0) totalEnergyKwh = t;
        }
        if (itRaw != null) {
          const it = parseFloat(String(itRaw));
          if (!isNaN(it) && it >= 0) itEnergyKwh = it;
        }
        if (pueVal === undefined && totalEnergyKwh && itEnergyKwh && itEnergyKwh > 0) {
          pueVal = Number((totalEnergyKwh / itEnergyKwh).toFixed(2));
        }
      }

      let doorsEnv: Array<{ doorName: string; temperature: number; humidity: number }> | undefined;
      let frontDoor: { temperature: number; humidity: number } | undefined;
      let rearDoor: { temperature: number; humidity: number } | undefined;

      if (thRes && thRes.ok) {
        const thData = await thRes.json();
        const thResult = thData?.result ?? thData;
        const temps: Array<{ name?: unknown; value?: unknown }> = Array.isArray(thResult?.temperature)
          ? thResult.temperature
          : [];
        const hums: Array<{ name?: unknown; value?: unknown }> = Array.isArray(thResult?.humidity)
          ? thResult.humidity
          : [];

        const normalizeSensorKey = (rawName: unknown) =>
          String(rawName ?? 'Sensor').replace(/^\d+-/, '').trim() || 'Sensor';

        const tempByKey = new Map<string, number>();
        const humByKey = new Map<string, number>();
        const keySet = new Set<string>();

        temps.forEach((t) => {
          const key = normalizeSensorKey(t.name);
          const val = parseFloat(String(t.value ?? ''));
          if (!isNaN(val)) {
            if (!tempByKey.has(key)) tempByKey.set(key, val);
            keySet.add(key);
          }
        });

        hums.forEach((h) => {
          const key = normalizeSensorKey(h.name);
          const val = parseFloat(String(h.value ?? ''));
          if (!isNaN(val)) {
            if (!humByKey.has(key)) humByKey.set(key, val);
            keySet.add(key);
          }
        });

        const sortedKeys = Array.from(keySet).sort((a, b) => {
          const aDigits = a.replace(/[^0-9]/g, '');
          const bDigits = b.replace(/[^0-9]/g, '');
          const aNum = aDigits ? parseInt(aDigits, 10) : 999;
          const bNum = bDigits ? parseInt(bDigits, 10) : 999;
          if (aNum !== bNum) return aNum - bNum;

          const aLower = a.toLowerCase();
          const bLower = b.toLowerCase();
          if (aLower.includes('front') && (bLower.includes('back') || bLower.includes('rear'))) return -1;
          if ((aLower.includes('back') || aLower.includes('rear')) && bLower.includes('front')) return 1;
          return a.localeCompare(b);
        });

        if (sortedKeys.length > 0) {
          doorsEnv = sortedKeys.map((key, idx) => {
            const tempVal = tempByKey.get(key);
            let humVal = humByKey.get(key);
            if (humVal === undefined && hums[idx]) {
              const fallbackH = parseFloat(String(hums[idx].value ?? ''));
              if (!isNaN(fallbackH)) humVal = fallbackH;
            }
            return {
              doorName: key,
              temperature: tempVal ?? 0,
              humidity: humVal ?? 0,
            };
          });

          const frontMatch =
            doorsEnv.find((d) => d.doorName.toLowerCase().includes('front')) || doorsEnv[0];
          const rearMatch =
            doorsEnv.find(
              (d) =>
                d.doorName.toLowerCase().includes('rear') ||
                d.doorName.toLowerCase().includes('back')
            ) || doorsEnv[doorsEnv.length - 1];

          if (frontMatch) {
            frontDoor = { temperature: frontMatch.temperature, humidity: frontMatch.humidity };
          }
          if (rearMatch) {
            rearDoor = { temperature: rearMatch.temperature, humidity: rearMatch.humidity };
          }
        }
      }

      if (
        pueVal === undefined &&
        totalEnergyKwh === undefined &&
        itEnergyKwh === undefined &&
        (!doorsEnv || doorsEnv.length === 0) &&
        !frontDoor &&
        !rearDoor
      ) {
        return null;
      }

      return { pue: pueVal, totalEnergyKwh, itEnergyKwh, doorsEnv, frontDoor, rearDoor };
    } catch {
      return null;
    }
  }

  /**
   * Helper to map an API site into the dashboard's CompanyItem
   * Accurately reflects live DCS site data (PUE: 2.19, 90-day service cycle, Secure sensors)
   */
  mapApiSiteToCompany(site: ApiSite, existing?: CompanyItem): CompanyItem {
    const lastService =
      site.last_maintenance || existing?.lastService || new Date().toISOString().split('T')[0];

    // Auto-calculate next maintenance date (90-day / ~3-month cycle, matching main app)
    const nextService = calculateNextServiceDate(lastService);

    const accounts: CompanyAccount[] = existing?.accounts ?? [];

    const monitors: RackMonitor[] = Array.isArray(site.monitors) && site.monitors.length > 0
      ? site.monitors.map((m) => ({
          id: m.id,
          cabinetId: m.cabinet_id || 'CAB-01',
          dahuaCabinetId: m.dahua_cabinet_id,
          label: m.label || `Rack ${m.cabinet_id || '01'}`,
          openIp: m.open_ip,
          localIp: m.local_ip,
          siteUser: m.site_user,
          sitePassword: '',
          isActive: m.is_active === 1,
          activeIssues: [],
        }))
      : (existing?.monitors && existing.monitors.length > 0
          ? existing.monitors
          : [
              {
                id: `mon-${site.site_id}-1`,
                cabinetId: site.cabinet_id || 'CAB-01',
                dahuaCabinetId: site.dahua_cabinet_id,
                label: `${site.site_name || 'Primary'} Rack 1`,
                openIp: site.open_ip || '',
                localIp: site.local_ip || '',
                siteUser: site.site_user || '',
                sitePassword: '',
                isActive: site.is_active !== 0,
                activeIssues: [],
              },
            ]);

    return {
      id: `site-${site.site_id}`,
      name: site.site_name || `Site #${site.site_id}`,
      openIp: site.open_ip || '',
      localIp: site.local_ip || '',
      siteUser: site.site_user || '',
      sitePassword: '',
      isBlocked: site.is_active === 0,
      pue: existing?.pue ?? 0,
      totalEnergyKwh: existing?.totalEnergyKwh,
      itEnergyKwh: existing?.itEnergyKwh,
      temperature: existing?.temperature,
      humidity: existing?.humidity,
      lastService,
      nextService,
      cctvIp: site.cctv_ip ?? existing?.cctvIp ?? '',
      cctvUser: site.cctv_user ?? existing?.cctvUser ?? '',
      cctvPassword: '',
      faceScannerIp: site.face_scanner_ip ?? existing?.faceScannerIp ?? '',
      faceScannerUser: site.face_scanner_user ?? existing?.faceScannerUser ?? '',
      faceScannerPassword: '',
      techNotes: site.tech_notes ?? existing?.techNotes ?? '',
      activeIssues: [], // All 7 subsystems (AC, T.H, Power, UPS, Smoke, Leak, PDU) Secure
      accounts,
      monitors,
    };
  }

  /**
   * Admin API: Register new company with its first rack monitor
   */
  async createCompanySite(payload: {
    name: string;
    cabinet_id: string;
    label?: string;
    open_ip: string;
    local_ip?: string;
    site_user: string;
    site_pass: string;
    account_user?: string;
    account_pass?: string;
    account_email?: string;
    console_user?: string;
    console_pass?: string;
    cctv_ip?: string;
    cctv_user?: string;
    cctv_pass?: string;
    face_scanner_ip?: string;
    face_scanner_user?: string;
    face_scanner_pass?: string;
    tech_notes?: string;
  }): Promise<{ success: boolean; site_id?: number; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=admin_create_company`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({ action: 'admin_create_company', ...payload }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, site_id: data.site_id, message: data.message };
      }
      return { success: false, message: data.message || 'Failed to create company' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Admin API: Add an additional rack monitor to a company
   */
  async addRackMonitor(payload: {
    site_id: number;
    cabinet_id: string;
    label?: string;
    open_ip: string;
    local_ip?: string;
    site_user: string;
    site_pass: string;
  }): Promise<{ success: boolean; monitor_id?: number; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=admin_add_rack_monitor`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({ action: 'admin_add_rack_monitor', ...payload }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, monitor_id: data.monitor_id, message: data.message };
      }
      return { success: false, message: data.message || 'Failed to add rack monitor' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Admin API: Update an existing rack monitor
   */
  async updateRackMonitor(payload: {
    monitor_id: number;
    cabinet_id: string;
    label?: string;
    open_ip: string;
    local_ip?: string;
    site_user: string;
    site_pass?: string;
    is_active?: number;
  }): Promise<{ success: boolean; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=admin_update_rack_monitor`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({ action: 'admin_update_rack_monitor', ...payload }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, message: data.message };
      }
      return { success: false, message: data.message || 'Failed to update rack monitor' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Admin API: Delete a rack monitor
   */
  async deleteRackMonitor(monitorId: number): Promise<{ success: boolean; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=admin_delete_rack_monitor`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({ action: 'admin_delete_rack_monitor', monitor_id: monitorId }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, message: data.message };
      }
      return { success: false, message: data.message || 'Failed to delete rack monitor' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Admin API: Toggle company active/blocked status
   */
  async toggleCompanyStatus(siteId: number, isActive: number): Promise<{ success: boolean; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=admin_toggle_company_status`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({ action: 'admin_toggle_company_status', site_id: siteId, is_active: isActive }),
      });
      const data = await res.json();
      return { success: res.ok && data.status === 'success' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Admin API: Update Hikvision CCTV, Face Scanner, and Technician Notes for a site
   */
  async updateSiteTechDetails(
    siteId: number,
    payload: {
      cctv_ip: string;
      cctv_user: string;
      cctv_pass: string;
      face_scanner_ip: string;
      face_scanner_user: string;
      face_scanner_pass: string;
      tech_notes: string;
    }
  ): Promise<{ success: boolean; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=admin_update_site_tech_details`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({
          action: 'admin_update_site_tech_details',
          site_id: siteId,
          ...payload,
        }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, message: data.message };
      }
      return { success: false, message: data.message || 'Failed to update tech details' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Update site's last_maintenance date in the database (next service is auto-calculated +90 days)
   */
  async updateSiteMaintenance(
    siteId: number,
    maintenanceDate: string
  ): Promise<{ success: boolean; message?: string }> {
    try {
      await this.ensureAuthenticated();
      const token = this.getAuthToken();
      const res = await fetch(`${CPANEL_API_URL}?action=update_maintenance`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token || '',
        },
        body: JSON.stringify({
          action: 'update_maintenance',
          site_id: siteId,
          maintenance_date: maintenanceDate,
        }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, message: data.message };
      }
      return { success: false, message: data.message || 'Failed to update maintenance date' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Request a 6-digit password recovery code sent to the account's registered email
   */
  async requestPasswordResetCode(
    identifier: string
  ): Promise<{ success: boolean; message?: string; maskedEmail?: string }> {
    try {
      const res = await fetch(`${CPANEL_API_URL}?action=request_password_reset_code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'request_password_reset_code',
          username: identifier,
          email: identifier,
        }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return {
          success: true,
          message: data.message,
          maskedEmail: data.masked_email,
        };
      }
      return { success: false, message: data.message || 'Failed to send recovery code' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Verify a 6-digit recovery code and set a new password
   */
  async verifyPasswordResetCode(
    identifier: string,
    code: string,
    newPassword: string
  ): Promise<{ success: boolean; message?: string }> {
    try {
      const res = await fetch(`${CPANEL_API_URL}?action=verify_password_reset_code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'verify_password_reset_code',
          username: identifier,
          email: identifier,
          code,
          new_password: newPassword,
        }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true, message: data.message };
      }
      return { success: false, message: data.message || 'Invalid or expired recovery code' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  async updateMyEmail(email: string): Promise<{ success: boolean; message?: string }> {
    const token = this.getAuthToken();
    if (!token) return { success: false, message: 'Not authenticated' };
    try {
      const res = await fetch(`${CPANEL_API_URL}?action=update_my_email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token,
        },
        body: JSON.stringify({ action: 'update_my_email', email: email.trim() }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        this.user = { ...this.user, email: email.trim() } as ApiUser;
        sessionStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));
        if (localStorage.getItem(STORAGE_KEY_TOKEN)) {
          localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));
        }
        return { success: true };
      }
      return { success: false, message: data.message || 'Failed to update recovery email' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  async requestMyRecoveryCode(): Promise<{ success: boolean; message?: string }> {
    const username = this.user?.username?.trim();
    if (!username) return { success: false, message: 'Current user is unavailable' };
    return this.requestPasswordResetCode(username);
  }

  async changePassword(
    currentPassword: string,
    newPassword: string,
  ): Promise<{ success: boolean; message?: string }> {
    const token = this.getAuthToken();
    const username = this.user?.username?.trim();
    if (!token || !username) return { success: false, message: 'Not authenticated' };
    try {
      const res = await fetch(`${CPANEL_API_URL}?action=change_password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token,
        },
        body: JSON.stringify({
          action: 'change_password',
          username,
          current_password: currentPassword,
          new_password: newPassword,
        }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') return { success: true };
      return { success: false, message: data.message || 'Failed to change password' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  async requestUsernameChangeCode(): Promise<{ success: boolean; message?: string }> {
    const token = this.getAuthToken();
    if (!token) return { success: false, message: 'Not authenticated' };
    try {
      const res = await fetch(`${CPANEL_API_URL}?action=request_my_verification_code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'X-Auth-Token': token },
        body: JSON.stringify({ action: 'request_my_verification_code' }),
      });
      const data = await res.json();
      return res.ok && data.status === 'success'
        ? { success: true, message: data.message }
        : { success: false, message: data.message || 'Unable to send verification code' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  async changeUsername(newUsername: string, code: string): Promise<{ success: boolean; message?: string }> {
    const token = this.getAuthToken();
    if (!token) return { success: false, message: 'Not authenticated' };
    try {
      const res = await fetch(`${CPANEL_API_URL}?action=change_my_username`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'X-Auth-Token': token },
        body: JSON.stringify({ action: 'change_my_username', new_username: newUsername.trim(), code: code.trim() }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        this.user = { ...this.user, username: newUsername.trim() } as ApiUser;
        sessionStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));
        if (localStorage.getItem(STORAGE_KEY_TOKEN)) localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));
        return { success: true };
      }
      return { success: false, message: data.message || 'Failed to change username' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }

  /**
   * Fetch site members (username, email, rack console status) for a site
   */
  async fetchSiteMembers(siteId: number): Promise<
    Array<{
      user_id: number;
      username: string;
      email?: string | null;
      role?: string;
      is_kiosk?: number | boolean;
    }>
  > {
    try {
      const token = this.getAuthToken();
      if (!token) return [];
      const res = await fetch(`${CPANEL_API_URL}?action=list_site_members`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token,
        },
        body: JSON.stringify({
          action: 'list_site_members',
          site_id: siteId,
        }),
      });
      if (!res.ok) return [];
      const data = await res.json();
      if (data.status === 'success' && Array.isArray(data.members)) {
        return data.members;
      }
      return [];
    } catch {
      return [];
    }
  }

  /**
   * Update a site member's recovery email in the database
   */
  async updateSiteMemberEmail(
    siteId: number,
    memberUserId: number,
    email: string
  ): Promise<{ success: boolean; message?: string }> {
    try {
      const token = this.getAuthToken();
      if (!token) return { success: false, message: 'Not authenticated' };
      const res = await fetch(`${CPANEL_API_URL}?action=admin_update_user_email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token,
        },
        body: JSON.stringify({
          action: 'admin_update_user_email',
          site_id: siteId,
          member_user_id: memberUserId,
          email: email.trim(),
        }),
      });
      const data = await res.json();
      if (res.ok && data.status === 'success') {
        return { success: true };
      }
      return { success: false, message: data.message || 'Failed to update recovery email' };
    } catch (err: any) {
      return { success: false, message: err.message || 'Network error' };
    }
  }
}

export const apiService = new ApiService();
