import { CompanyItem } from './types';

export const INITIAL_COMPANIES: CompanyItem[] = [
  {
    id: 'comp-1',
    name: 'DCS HQ Office',
    openIp: '219.92.246.237',
    localIp: '172.16.200.2',
    siteUser: 'admin',
    sitePassword: 'Dtct+123',
    isBlocked: false,
    pue: 2.19,
    totalEnergyKwh: 610.25,
    itEnergyKwh: 273.83,
    temperature: 33,
    humidity: 38,
    lastService: '2026-11-05',
    nextService: '2027-02-03',
    activeIssues: [], // All subsystems Secure (AC, T.H, Power, UPS, Smoke, Leak, PDU)
    accounts: [
      {
        id: 'acc-1',
        username: 'admin',
        password: 'Dtct+123',
        isRackConsole: false,
      },
      {
        id: 'acc-2',
        username: 'rack_console',
        password: 'Console#Access88',
        isRackConsole: true,
      },
    ],
    monitors: [
      {
        id: 'mon-1-1',
        cabinetId: 'CAB-01',
        label: 'Core Switch & Gateway Rack',
        openIp: '219.92.246.237',
        localIp: '172.16.200.2',
        siteUser: 'admin',
        sitePassword: 'Dtct+123',
        isActive: true,
        pue: 2.19,
        temperature: 33,
        humidity: 38,
        frontDoor: {
          temperature: 24.5,
          humidity: 48,
        },
        rearDoor: {
          temperature: 33.0,
          humidity: 38,
        },
        activeIssues: [],
      },
      {
        id: 'mon-1-2',
        cabinetId: 'CAB-02',
        label: 'Production Database Rack',
        openIp: '219.92.246.237',
        localIp: '172.16.200.3',
        siteUser: 'admin',
        sitePassword: 'Dtct+123',
        isActive: true,
        pue: 1.45,
        temperature: 28,
        humidity: 42,
        frontDoor: {
          temperature: 23.8,
          humidity: 46,
        },
        rearDoor: {
          temperature: 31.5,
          humidity: 40,
        },
        activeIssues: [],
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
    monitors: [
      {
        id: 'mon-2-1',
        cabinetId: 'CAB-01',
        label: 'Main Server Rack',
        openIp: '175.143.12.88',
        localIp: '10.0.10.45',
        siteUser: 'admin_2',
        sitePassword: 'SecurePassword!890',
        isActive: true,
        pue: 1.35,
        temperature: 26,
        humidity: 45,
        frontDoor: {
          temperature: 24.0,
          humidity: 50,
        },
        rearDoor: {
          temperature: 32.2,
          humidity: 42,
        },
        activeIssues: [],
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
    monitors: [
      {
        id: 'mon-3-1',
        cabinetId: 'CAB-01',
        label: 'Auxiliary Storage Rack',
        openIp: '115.132.89.14',
        localIp: '172.16.2.10',
        siteUser: 'admin_3',
        sitePassword: 'MasterKey!2026',
        isActive: false,
        pue: 1.58,
        temperature: 36,
        humidity: 65,
        frontDoor: {
          temperature: 28.5,
          humidity: 62,
        },
        rearDoor: {
          temperature: 38.0,
          humidity: 55,
        },
        activeIssues: ['Unsecure AC', 'Power'],
      },
    ],
  },
];

const STORAGE_KEY_COMPANIES = 'dcstack_monitor_companies_v7';
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
