import { CompanyItem, CompanyAccount } from '../types';

export const CPANEL_API_URL = 'https://portal.dcstack.my/api/index.php';
const STORAGE_KEY_TOKEN = 'dcstack_api_token';
const STORAGE_KEY_USER = 'dcstack_api_user';

export interface ApiUser {
  id: number;
  username: string;
  license_type?: string;
  expiry_date?: string;
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
}

class ApiService {
  private token: string | null = null;
  private user: ApiUser | null = null;

  constructor() {
    this.token = localStorage.getItem(STORAGE_KEY_TOKEN);
    const cachedUser = localStorage.getItem(STORAGE_KEY_USER);
    if (cachedUser) {
      try {
        this.user = JSON.parse(cachedUser);
      } catch {
        this.user = null;
      }
    }
  }

  getAuthToken(): string | null {
    return this.token || localStorage.getItem(STORAGE_KEY_TOKEN);
  }

  getUser(): ApiUser | null {
    return this.user;
  }

  isAuthenticated(): boolean {
    return Boolean(this.getAuthToken());
  }

  logout() {
    this.token = null;
    this.user = null;
    localStorage.removeItem(STORAGE_KEY_TOKEN);
    localStorage.removeItem(STORAGE_KEY_USER);
  }

  /**
   * Login against https://portal.dcstack.my/api/index.php?action=login
   */
  async login(username: string, password: string): Promise<{
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
      formParams.append('remember_me', '1');

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
        this.token = data.auth_token;
        this.user = data.user || { id: 3, username };

        localStorage.setItem(STORAGE_KEY_TOKEN, this.token!);
        localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(this.user));

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
    const token = this.getAuthToken();
    if (!token) {
      return { success: false, sites: [], message: 'Not authenticated' };
    }

    try {
      const response = await fetch(`${CPANEL_API_URL}?action=get_sites`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'X-Auth-Token': token,
        },
      });

      if (!response.ok) {
        return { success: false, sites: [], message: `HTTP ${response.status}` };
      }

      const data = await response.json();
      if (data.status === 'success' && Array.isArray(data.sites)) {
        return { success: true, sites: data.sites };
      }

      return { success: false, sites: [], message: data.message || 'No sites found' };
    } catch (err: any) {
      return { success: false, sites: [], message: err.message };
    }
  }

  /**
   * Helper to map an API site into the dashboard's CompanyItem
   */
  mapApiSiteToCompany(site: ApiSite, existing?: CompanyItem): CompanyItem {
    const lastService = site.last_maintenance || existing?.lastService || '2026-11-05';

    // Calculate a realistic expected service (30-60 days after last maintenance)
    let nextService = existing?.nextService || '2026-12-15';
    if (!existing && site.last_maintenance) {
      try {
        const last = new Date(site.last_maintenance);
        last.setDate(last.getDate() + 45);
        nextService = last.toISOString().split('T')[0];
      } catch {
        nextService = '2026-12-15';
      }
    }

    const accounts: CompanyAccount[] = existing?.accounts && existing.accounts.length > 0
      ? existing.accounts
      : [
          {
            id: `acc-site-${site.site_id}-1`,
            username: site.site_user || 'admin',
            password: site.site_pass || 'Dtct+123',
            isRackConsole: false,
          },
          {
            id: `acc-site-${site.site_id}-2`,
            username: 'rack_console',
            password: 'Console#Access88',
            isRackConsole: true,
          },
        ];

    return {
      id: `site-${site.site_id}`,
      name: site.site_name || 'Data Center Specialist',
      openIp: site.open_ip || '219.92.246.237',
      localIp: site.local_ip || '172.16.200.2',
      siteUser: site.site_user || 'admin',
      sitePassword: site.site_pass || 'Dtct+123',
      isBlocked: site.is_active === 0,
      pue: existing?.pue || 1.24,
      lastService,
      nextService,
      activeIssues: existing?.activeIssues || [],
      accounts,
    };
  }
}

export const apiService = new ApiService();
