import { CompanyItem } from './types';

export const INITIAL_COMPANIES: CompanyItem[] = [
  {
    id: 'comp-1',
    name: 'Data Center Specialist',
    openIp: '219.92.246.237',
    localIp: '192.168.1.120',
    siteUser: 'admin',
    sitePassword: 'Dtct+1234',
    isBlocked: false,
    pue: 1.24,
    lastService: '2026-10-12',
    nextService: '2026-12-15',
    activeIssues: ['Smoke'], // Only has Smoke
    accounts: [
      {
        id: 'acc-1',
        username: 'ops_user',
        password: 'User@2026',
        isRackConsole: false,
      },
      {
        id: 'acc-2',
        username: 'rack_console',
        password: 'Console#Access88',
        isRackConsole: true,
      },
    ],
  },
  {
    id: 'comp-2',
    name: 'Company 2',
    openIp: '175.143.12.88',
    localIp: '10.0.10.45',
    siteUser: 'admin_2',
    sitePassword: 'SecurePassword!890',
    isBlocked: false,
    pue: 1.35,
    lastService: '2026-09-01',
    nextService: '2026-12-01',
    activeIssues: [], // No issues -> Displays "None"
    accounts: [
      {
        id: 'acc-3',
        username: 'account_user',
        password: 'AccountPass#1',
        isRackConsole: false,
      },
      {
        id: 'acc-4',
        username: 'rack_console_2',
        password: 'ConsoleKey@2026',
        isRackConsole: true,
      },
    ],
  },
  {
    id: 'comp-3',
    name: 'Company 3',
    openIp: '115.132.89.14',
    localIp: '172.16.2.10',
    siteUser: 'admin_3',
    sitePassword: 'MasterKey!2026',
    isBlocked: true, // Blocked
    pue: 1.58,
    lastService: '2026-07-15',
    nextService: '2026-10-20', // Overdue
    activeIssues: ['Unsecure AC', 'Power'], // Shows active issues only
    accounts: [
      {
        id: 'acc-5',
        username: 'operator_3',
        password: 'OpPassword#99',
        isRackConsole: false,
      },
      {
        id: 'acc-6',
        username: 'console_3',
        password: 'ConsolePin$443',
        isRackConsole: true,
      },
    ],
  },
];

const STORAGE_KEY_COMPANIES = 'dcstack_monitor_companies_v4';
const STORAGE_KEY_EMAIL = 'dcstack_monitor_recovery_email_v1';

export function loadCompanies(): CompanyItem[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY_COMPANIES);
    if (!raw) {
      localStorage.setItem(STORAGE_KEY_COMPANIES, JSON.stringify(INITIAL_COMPANIES));
      return INITIAL_COMPANIES;
    }
    return JSON.parse(raw);
  } catch {
    return INITIAL_COMPANIES;
  }
}

export function saveCompanies(companies: CompanyItem[]) {
  localStorage.setItem(STORAGE_KEY_COMPANIES, JSON.stringify(companies));
}

export function loadRecoveryEmail(): string {
  return localStorage.getItem(STORAGE_KEY_EMAIL) || 'admin@dcstack.my';
}

export function saveRecoveryEmail(email: string) {
  localStorage.setItem(STORAGE_KEY_EMAIL, email);
}
