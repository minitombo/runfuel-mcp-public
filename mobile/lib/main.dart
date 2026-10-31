import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

const _mint = Color(0xFF54E0B8);
const _navy = Color(0xFF0B1220);
const _panel = Color(0xFF151F30);
const _muted = Color(0xFF9BAAC0);
const _repoUrl = 'https://github.com/minitombo/runfuel-mcp-public';
const _vercelImportUrl =
    'https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fminitombo%2Frunfuel-mcp-public';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RunFuelDatabase.instance.open();
  await RunFuelSettings.load();
  runApp(const RunFuelApp());
}

class RunFuelSettings {
  static String backendUrl = '';
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    backendUrl = prefs.getString('backend_url') ?? '';
  }

  static Future<void> saveBackendUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    backendUrl = value.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString('backend_url', backendUrl);
  }
}

class RunFuelDatabase {
  RunFuelDatabase._();
  static final instance = RunFuelDatabase._();
  Database? _db;

  Future<void> open() async {
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'runfuel_v1.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activities (
            id TEXT PRIMARY KEY, started_at TEXT NOT NULL,
            sport TEXT, distance_m REAL, duration_s REAL,
            avg_hr REAL, avg_pace_s_per_km REAL, raw_json TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE nutrition_days (
            day TEXT PRIMARY KEY, calories REAL, protein_g REAL,
            carbs_g REAL, fat_g REAL, raw_json TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE coaching_reviews (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL, prompt TEXT, response TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_state (
            source TEXT PRIMARY KEY, last_attempt TEXT,
            last_success TEXT, status TEXT, message TEXT
          )
        ''');
      },
    );
  }
}

class RunFuelApp extends StatelessWidget {
  const RunFuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _mint,
      brightness: Brightness.dark,
      surface: _panel,
    );
    return MaterialApp(
      title: 'RunFuel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _navy,
        appBarTheme: const AppBarTheme(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: _panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const RunFuelShell(),
    );
  }
}

class RunFuelShell extends StatefulWidget {
  const RunFuelShell({super.key});
  @override
  State<RunFuelShell> createState() => _RunFuelShellState();
}

class _RunFuelShellState extends State<RunFuelShell> {
  int _index = 0;
  bool _checking = false;
  String _connectionMessage = 'Not connected';

  Future<void> _checkBackend() async {
    if (RunFuelSettings.backendUrl.isEmpty) {
      _notice('Add your own RunFuel backend in Settings first.');
      return;
    }
    setState(() {
      _checking = true;
      _connectionMessage = 'Checking…';
    });
    try {
      final response = await http
          .get(Uri.parse('${RunFuelSettings.backendUrl}/health'))
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _connectionMessage =
            response.statusCode == 200 ? 'Backend reachable' : 'HTTP ${response.statusCode}';
      });
      _notice(response.statusCode == 200
          ? 'Backend health check passed. Data sync will be enabled in the next integration milestone.'
          : 'Backend returned HTTP ${response.statusCode}.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _connectionMessage = 'Connection failed');
      _notice('Could not reach your backend. Check the URL and connection.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        connectionMessage: _connectionMessage,
        checking: _checking,
        onCheckBackend: _checkBackend,
        onOpenSettings: _openSettings,
      ),
      const TrainingPage(),
      const NutritionPage(),
      const CoachPage(),
      const ProgressPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: _mint, size: 27),
            const SizedBox(width: 8),
            const Text('RunFuel', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _mint.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('BETA', style: TextStyle(
                color: _mint, fontSize: 9, fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              )),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings and connections',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: const Color(0xFF101A29),
        indicatorColor: _mint.withValues(alpha: .16),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.directions_run_rounded), label: 'Training'),
          NavigationDestination(icon: Icon(Icons.restaurant_rounded), label: 'Fuel'),
          NavigationDestination(icon: Icon(Icons.forum_rounded), label: 'Coach'),
          NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Progress'),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) setState(() {});
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.connectionMessage,
    required this.checking,
    required this.onCheckBackend,
    required this.onOpenSettings,
  });
  final String connectionMessage;
  final bool checking;
  final VoidCallback onCheckBackend;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        const Text('YOUR DAILY RUNNING HQ',
            style: TextStyle(color: _muted, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        const Text('Ready when you are.',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Your training, fuelling and recovery in one place.',
            style: TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF153C3A), Color(0xFF17283B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _mint.withValues(alpha: .18)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.spa_rounded, color: _mint),
                SizedBox(width: 8),
                Text('TODAY', style: TextStyle(
                  color: _mint, fontSize: 11, fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                )),
              ]),
              SizedBox(height: 16),
              Text('Your data will appear here',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              SizedBox(height: 7),
              Text('Connect your RunFuel backend and sync your first Garmin and MyFitnessPal data.',
                  style: TextStyle(color: Color(0xFFD0DCE6), height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _MetricCard(
            icon: Icons.directions_run_rounded, label: 'RUNNING',
            value: '—', detail: 'No activities synced',
          )),
          const SizedBox(width: 12),
          Expanded(child: _MetricCard(
            icon: Icons.battery_charging_full_rounded, label: 'RECOVERY',
            value: '—', detail: 'Awaiting Garmin',
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MetricCard(
            icon: Icons.local_fire_department_rounded, label: 'CALORIES',
            value: '—', detail: 'Awaiting diary',
          )),
          const SizedBox(width: 12),
          Expanded(child: _MetricCard(
            icon: Icons.restaurant_rounded, label: 'PROTEIN',
            value: '—', detail: 'Awaiting diary',
          )),
        ]),
        const SizedBox(height: 20),
        _SectionTitle(title: 'CONNECTIONS', action: 'Manage', onTap: onOpenSettings),
        const SizedBox(height: 10),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _ConnectionRow(
              icon: Icons.cloud_outlined,
              title: 'RunFuel backend',
              subtitle: RunFuelSettings.backendUrl.isEmpty
                  ? 'Add your own deployment URL'
                  : RunFuelSettings.backendUrl,
              status: connectionMessage,
            ),
            const Divider(height: 24, color: Color(0xFF29364A)),
            _ConnectionRow(
              icon: Icons.watch_outlined,
              title: 'Garmin Connect',
              subtitle: 'Connect through your own backend',
              status: 'Not checked',
            ),
            const Divider(height: 24, color: Color(0xFF29364A)),
            _ConnectionRow(
              icon: Icons.restaurant_menu_rounded,
              title: 'MyFitnessPal',
              subtitle: 'Read-only food diary connection',
              status: 'Not checked',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: checking ? null : onCheckBackend,
                icon: checking
                    ? const SizedBox(width: 17, height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering_rounded),
                label: Text(checking ? 'Checking backend…' : 'Check backend connection'),
                style: FilledButton.styleFrom(
                  backgroundColor: _mint, foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        )),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'NEXT UP'),
        const SizedBox(height: 10),
        const _EmptyCard(
          icon: Icons.calendar_month_rounded,
          title: 'Training calendar',
          text: 'Your scheduled and completed workouts will show here after sync is connected.',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label,
    required this.value, required this.detail});
  final IconData icon;
  final String label, value, detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _mint, size: 20),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.1)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      Text(detail, style: const TextStyle(color: _muted, fontSize: 10)),
    ]),
  ));
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.icon, required this.title,
    required this.subtitle, required this.status});
  final IconData icon;
  final String title, subtitle, status;
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: _mint, size: 20),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 11)),
    ])),
    const SizedBox(width: 8),
    Flexible(child: Text(status, textAlign: TextAlign.end,
        style: const TextStyle(color: _muted, fontSize: 10))),
  ]);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: const TextStyle(color: _muted, fontSize: 11,
        fontWeight: FontWeight.w800, letterSpacing: 1.4)),
    const Spacer(),
    if (action != null) TextButton(onPressed: onTap,
        child: Text(action!, style: const TextStyle(color: _mint))),
  ]);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(18),
    child: Row(children: [
      Icon(icon, color: _mint, size: 27),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4)),
      ])),
    ]),
  ));
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});
  @override
  Widget build(BuildContext context) => const _FeaturePage(
    eyebrow: 'TRAINING',
    title: 'Build consistency.',
    subtitle: 'Your training calendar, Garmin activities and structured sessions.',
    icon: Icons.directions_run_rounded,
    items: [
      ('Scheduled workouts', 'Your planned sessions will appear here.'),
      ('Completed activities', 'Runs, distance, duration, pace and heart rate.'),
      ('Training progression', 'Weekly distance and gradual return-to-running trends.'),
    ],
  );
}

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});
  @override
  Widget build(BuildContext context) => const _FeaturePage(
    eyebrow: 'NUTRITION',
    title: 'Fuel the work.',
    subtitle: 'A clear view of intake, macros and running fuelling.',
    icon: Icons.restaurant_rounded,
    items: [
      ('Food diary', 'MyFitnessPal daily entries and meal totals.'),
      ('Macro balance', 'Calories, protein, carbohydrates and fat.'),
      ('Run fuelling', 'Practical pre-run and recovery recommendations.'),
    ],
  );
}

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({required this.eyebrow, required this.title,
    required this.subtitle, required this.icon, required this.items});
  final String eyebrow, title, subtitle;
  final IconData icon;
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    Text(eyebrow, style: const TextStyle(color: _mint, fontSize: 11,
        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
    const SizedBox(height: 8),
    Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    Text(subtitle, style: const TextStyle(color: _muted)),
    const SizedBox(height: 22),
    for (final item in items) ...[
      _EmptyCard(icon: icon, title: item.$1, text: item.$2),
      const SizedBox(height: 10),
    ],
    const SizedBox(height: 10),
    const Text('Connect and sync your own RunFuel backend to populate this section.',
        style: TextStyle(color: _muted, fontSize: 12)),
  ]);
}

class CoachPage extends StatelessWidget {
  const CoachPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('AI RUNNING COACH', style: TextStyle(color: _mint,
        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
    const SizedBox(height: 8),
    const Text('Honest coaching.\\nBetter decisions.',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
    const SizedBox(height: 8),
    const Text('OpenAI will analyse your actual training and nutrition data when the secure AI backend is connected.',
        style: TextStyle(color: _muted, height: 1.45)),
    const SizedBox(height: 22),
    const _EmptyCard(icon: Icons.psychology_alt_rounded,
      title: 'Coach is being connected',
      text: 'Your AI key will stay on the server. It will never be embedded in this APK.'),
    const SizedBox(height: 12),
    const _EmptyCard(icon: Icons.fact_check_rounded,
      title: 'Daily review',
      text: 'Training, recovery, food diary and practical recommendations in one review.'),
    const SizedBox(height: 12),
    const _EmptyCard(icon: Icons.history_rounded,
      title: 'Saved conversations',
      text: 'Reviews and coaching history will be stored locally on this device.'),
  ]);
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) => const _FeaturePage(
    eyebrow: 'YOUR PROGRESS',
    title: 'Small steps add up.',
    subtitle: 'Long-term trends, not one-day noise.',
    icon: Icons.insights_rounded,
    items: [
      ('Weight trend', 'Track progress towards your chosen goal.'),
      ('Running consistency', 'Weekly volume and long-run progression.'),
      ('Recovery trends', 'Sleep, resting heart rate and readiness context.'),
    ],
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _urlController;
  bool _checking = false;
  String _health = 'Not checked';

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: RunFuelSettings.backendUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _urlController.text.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _message('Enter a valid HTTPS URL for your own RunFuel deployment.');
      return;
    }
    await RunFuelSettings.saveBackendUrl(value);
    if (mounted) _message('Backend URL saved on this device.');
  }

  Future<void> _test() async {
    await _save();
    if (RunFuelSettings.backendUrl.isEmpty) return;
    setState(() => _checking = true);
    try {
      final response = await http.get(
        Uri.parse('${RunFuelSettings.backendUrl}/health'),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => _health = response.statusCode == 200
          ? 'Healthy · HTTP 200' : 'HTTP ${response.statusCode}');
    } catch (_) {
      if (mounted) setState(() => _health = 'Could not connect');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _message('Could not open the link.');
    }
  }

  Future<void> _openTokenManager() async {
    if (RunFuelSettings.backendUrl.isEmpty) {
      _message('Save your own backend URL first.');
      return;
    }
    await _open('${RunFuelSettings.backendUrl}/settings');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Setup & connections')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('YOUR RUNFUEL INSTANCE', style: TextStyle(color: _mint,
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      const SizedBox(height: 8),
      const Text('Connect your own backend',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Each RunFuel installation uses its own GitHub fork, Vercel project, Redis database and service credentials.',
          style: TextStyle(color: _muted, height: 1.4)),
      const SizedBox(height: 18),
      _SetupStep(number: '01', title: 'Public GitHub source',
          detail: 'Use the official public RunFuel repository as the source for your own deployment.',
          button: 'Open GitHub repository', onTap: () => _open(_repoUrl)),
      _SetupStep(number: '02', title: 'Deploy to Vercel',
          detail: 'Import the public repository into your own Vercel account. Configure your own environment variables and Redis integration.',
          button: 'Import into Vercel', onTap: () => _open(_vercelImportUrl)),
      _SetupStep(number: '03', title: 'Configure backend URL',
          detail: 'Enter the HTTPS domain assigned to your own Vercel deployment.',
          child: TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'https://your-runfuel-project.vercel.app',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          )),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: _save, child: const Text('Save backend URL'))),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _checking ? null : _test,
        icon: _checking ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.health_and_safety_outlined),
        label: Text(_checking ? 'Checking…' : 'Test backend · $_health'),
      ),
      const SizedBox(height: 12),
      _SetupStep(number: '04', title: 'Credential manager',
          detail: 'Open your own RunFuel Token Manager to update Garmin and MyFitnessPal credentials securely.',
          button: 'Open token manager', onTap: _openTokenManager),
      _SetupStep(number: '05', title: 'Upstash Redis',
          detail: 'Create a dedicated Redis database for this deployment. Never reuse another RunFuel installation’s credentials.',
          button: 'Open Upstash console', onTap: () => _open('https://console.upstash.com/')),
      const SizedBox(height: 18),
      const _SectionTitle(title: 'SECURITY'),
      const SizedBox(height: 8),
      const _EmptyCard(icon: Icons.lock_outline_rounded,
        title: 'Secrets stay off the phone',
        text: 'OpenAI keys, Garmin keys, MyFitnessPal cookies and Vercel management credentials must remain on your secure backend. This app does not ask you to paste them here.'),
      const SizedBox(height: 12),
      const _EmptyCard(icon: Icons.gps_off_rounded,
        title: 'GPS is on demand',
        text: 'Routine sync and daily coaching will not request detailed GPS tracks. Route data is only requested for an activity when you ask for route analysis.'),
    ]),
  );
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.title,
    required this.detail, this.button, this.onTap, this.child});
  final String number, title, detail;
  final String? button;
  final VoidCallback? onTap;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(15), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(number, style: const TextStyle(color: _mint,
              fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
        const SizedBox(height: 7),
        Text(detail, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4)),
        if (child != null) ...[const SizedBox(height: 12), child!],
        if (button != null) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: onTap, child: Text(button!))),
        ],
      ],
    )),
  );
}
