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

export interface DoorEnvironment {
  temperature: number;
  humidity: number;
}

export interface RackMonitor {
  id: string | number;
  cabinetId: string;
  dahuaCabinetId?: string;
  label: string;
  openIp: string;
  localIp?: string;
  siteUser: string;
  sitePassword?: string;
  isActive: boolean;
  pue?: number;
  temperature?: number;
  humidity?: number;
  frontDoor?: DoorEnvironment;
  rearDoor?: DoorEnvironment;
  doorsEnv?: Array<{
    doorName: string;
    temperature: number;
    humidity: number;
  }>;
  activeIssues?: MonitorIssueType[];
}

export interface CompanyItem {
  id: string;
  name: string;
  openIp: string;
  localIp: string;
  siteUser: string;
  sitePassword: string;
  isBlocked: boolean; // Block button in case user doesn't pay
  pue: number;
  totalEnergyKwh?: number;
  itEnergyKwh?: number;
  temperature?: number;
  humidity?: number;
  lastService: string; // YYYY-MM-DD
  nextService: string; // YYYY-MM-DD
  activeIssues: MonitorIssueType[]; // Only issues that exist! If empty -> "None"
  accounts: CompanyAccount[];
  monitors?: RackMonitor[];
}

export type CompanyFilter = 'all' | 'active' | 'blocked' | 'issues';
