export interface CompanyAccount {
  id: string;
  username: string;
  password: string;
  isRackConsole: boolean; // true = Rack Console, false = Standard Account
}

export type MonitorIssueType =
  | 'Unsecure AC'
  | 'T.H'
  | 'Power'
  | 'UPS'
  | 'Smoke'
  | 'Leak'
  | 'PDU';

export const ALL_ISSUE_TYPES: MonitorIssueType[] = [
  'Unsecure AC',
  'T.H',
  'Power',
  'UPS',
  'Smoke',
  'Leak',
  'PDU',
];

export interface CompanyItem {
  id: string;
  name: string;
  openIp: string;
  localIp: string;
  siteUser: string;
  sitePassword: string;
  isBlocked: boolean; // Block button in case user doesn't pay
  pue: number;
  lastService: string; // YYYY-MM-DD
  nextService: string; // YYYY-MM-DD
  activeIssues: MonitorIssueType[]; // Only issues that exist! If empty -> "None"
  accounts: CompanyAccount[];
}

export type CompanyFilter = 'all' | 'active' | 'blocked' | 'issues';
