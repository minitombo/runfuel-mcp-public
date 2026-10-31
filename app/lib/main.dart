import 'package:file_picker/file_picker.dart';
import 'data/runfuel_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _green = Color(0xFF9BE15D);
const _bg = Color(0xFF101410);
const _panel = Color(0xFF1A211B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RunFuelDatabase.instance.initialize();
  runApp(const RunFuelApp());
}

class RunFuelApp extends StatelessWidget {
  const RunFuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
      surface: _bg,
    );
    return MaterialApp(
      title: 'RunFuel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _bg,
        cardColor: _panel,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _panel,
          indicatorColor: _green.withValues(alpha: .18),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
  final _pages = const [
    HomePage(),
    TrainingPage(),
    CoachPage(),
    NutritionPage(),
    HealthPage(),
    SettingsPage(),
  ];

  final _titles = const [
    'RunFuel',
    'Training',
    'AI Coach',
    'Nutrition',
    'Health profile',
    'Settings',
  ];

  Future<void> _manualSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backend sync is not connected yet. Complete the API setup first.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt, color: _green),
            const SizedBox(width: 8),
            Text(_titles[_index], style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          if (_index == 0)
            IconButton(
              tooltip: 'Manual sync',
              onPressed: _manualSync,
              icon: const Icon(Icons.sync),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Training'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Coach'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Food'),
          NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'Health'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: children,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.label, this.value, this.unit, this.icon, {super.key});
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _green, size: 20),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            Text(unit, style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 11)),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => PageBody(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_green.withValues(alpha: .22), _panel]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR TRAINING. YOUR DATA. YOUR COACH.', style: TextStyle(color: _green, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text('Build consistency.', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('Your personal running, nutrition and recovery workspace. Sync manually when you are ready.', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SectionTitle('Today at a glance'),
        const Row(
          children: [
            Expanded(child: MetricCard('Distance', '--', 'km today', Icons.directions_run)),
            SizedBox(width: 10),
            Expanded(child: MetricCard('Calories', '--', 'kcal logged', Icons.local_fire_department_outlined)),
            SizedBox(width: 10),
            Expanded(child: MetricCard('Recovery', '--', 'readiness', Icons.favorite_border)),
          ],
        ),
        const SectionTitle('Connections'),
        const ConnectionTile(name: 'Garmin', detail: 'Manual sync · not connected', icon: Icons.watch_outlined),
        const ConnectionTile(name: 'MyFitnessPal', detail: 'Manual sync · not connected', icon: Icons.restaurant_outlined),
        const ConnectionTile(name: 'OpenAI coach', detail: 'API setup required', icon: Icons.auto_awesome),
        const SectionTitle('Next step'),
        const InfoPanel(
          icon: Icons.link,
          title: 'Connect your RunFuel backend',
          body: 'Open Settings to configure your own deployment. The app currently runs in preview mode and does not retrieve personal data.',
        ),
      ]);
}

class ConnectionTile extends StatelessWidget {
  const ConnectionTile({super.key, required this.name, required this.detail, required this.icon});
  final String name;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Icon(icon, color: _green),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(detail, style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ]),
      );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _green),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ])),
        ]),
      );
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(children: [
        InfoPanel(icon: Icons.calendar_month, title: 'Training calendar', body: 'Your scheduled sessions and completed Garmin activities will appear here after the backend connection is implemented.'),
        SectionTitle('Training priorities'),
        ConnectionTile(name: 'Build consistency', detail: 'Gradual return to regular running', icon: Icons.trending_up),
        ConnectionTile(name: 'Long-run progression', detail: 'Progress towards regular 10 km runs', icon: Icons.route),
        ConnectionTile(name: 'Training load', detail: 'Avoid sudden increases in distance or intensity', icon: Icons.monitor_heart_outlined),
      ]);
}

class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(children: [
        InfoPanel(icon: Icons.auto_awesome, title: 'Your OpenAI running coach', body: 'The coaching interface is scaffolded. Once the secure backend AI endpoint is implemented, you will be able to ask questions, request daily reviews and analyse selected health documents.'),
        SectionTitle('Coaching principles'),
        ConnectionTile(name: 'Honest feedback', detail: 'Challenge assumptions and explain uncertainty', icon: Icons.fact_check_outlined),
        ConnectionTile(name: 'Evidence-led', detail: 'Use actual training and nutrition data', icon: Icons.analytics_outlined),
        ConnectionTile(name: 'Cost controlled', detail: 'No AI requests without your action', icon: Icons.savings_outlined),
      ]);
}

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(children: [
        InfoPanel(icon: Icons.restaurant, title: 'Nutrition diary', body: 'MyFitnessPal diary summaries and macro trends will be shown here after manual sync is connected.'),
        SectionTitle('Daily targets'),
        Row(children: [
          Expanded(child: MetricCard('Energy', '--', 'kcal', Icons.local_fire_department_outlined)),
          SizedBox(width: 10),
          Expanded(child: MetricCard('Protein', '--', 'grams', Icons.egg_alt_outlined)),
        ]),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: MetricCard('Carbs', '--', 'grams', Icons.bakery_dining_outlined)),
          SizedBox(width: 10),
          Expanded(child: MetricCard('Fibre', '--', 'grams', Icons.grass_outlined)),
        ]),
      ]);
}

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final List<String> _selectedFiles = [];

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: false,
    );
    if (result != null && mounted) {
      setState(() => _selectedFiles.addAll(result.files.map((f) => f.name)));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File selected locally. Secure upload and AI analysis will be enabled in a later integration step.')),
      );
    }
  }

  Future<void> _takePhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() => _selectedFiles.add(image.name));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo selected locally. It has not been uploaded or shared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        const InfoPanel(
          icon: Icons.health_and_safety,
          title: 'Health & athlete profile',
          body: 'Keep medical documents, test results, injuries and training limitations together. You choose what is shared with the AI coach.',
        ),
        const SectionTitle('Add information'),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _pickDocument, icon: const Icon(Icons.upload_file), label: const Text('Choose file'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Take photo'))),
        ]),
        const SectionTitle('Health records'),
        if (_selectedFiles.isEmpty)
          const InfoPanel(icon: Icons.folder_open, title: 'No files selected', body: 'Supported first-stage selections: PDF, JPG, PNG and WebP. Files remain on this device in this prototype.')
        else
          ..._selectedFiles.map((name) => ConnectionTile(name: name, detail: 'Selected on this device · not uploaded', icon: Icons.description_outlined)),
        const SectionTitle('Profile categories'),
        const ConnectionTile(name: 'Injuries and limitations', detail: 'Current and previous injuries, restrictions', icon: Icons.healing),
        const ConnectionTile(name: 'Blood tests and results', detail: 'Dated measurements, units and reference ranges', icon: Icons.science_outlined),
        const ConnectionTile(name: 'Medical guidance', detail: 'Clinician recommendations and follow-up', icon: Icons.medical_information_outlined),
      ]);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _endpoint = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _endpoint.text = prefs.getString('backend_url') ?? '';
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final value = _endpoint.text.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid HTTPS backend URL.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend URL saved on this device.')));
    }
  }

  Future<void> _openSettings() async {
    final base = _endpoint.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save your backend URL first.')));
      return;
    }
    final uri = Uri.tryParse('$base/settings');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        const InfoPanel(icon: Icons.settings, title: 'Connection setup', body: 'RunFuel is designed to use your own public-repository deployment. No maintainer credentials or shared backend are built into this app.'),
        const SectionTitle('Your backend'),
        TextField(
          controller: _endpoint,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Backend base URL',
            hintText: 'https://your-runfuel-domain.vercel.app',
            prefixIcon: Icon(Icons.cloud_outlined),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _loaded ? _save : null, icon: const Icon(Icons.save_outlined), label: const Text('Save backend URL')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _openSettings, icon: const Icon(Icons.open_in_new), label: const Text('Open token manager')),
        const SectionTitle('Security'),
        const InfoPanel(icon: Icons.lock_outline, title: 'Secrets are not embedded', body: 'The app does not contain Vercel, Garmin, MyFitnessPal or OpenAI secrets. The secure credential and OAuth flows still need to be connected to the backend.'),
        const SectionTitle('Sync policy'),
        const ConnectionTile(name: 'Manual only', detail: 'No automatic sync or background polling', icon: Icons.sync),
        const ConnectionTile(name: 'GPS tracks', detail: 'Only retrieve when you explicitly request route analysis', icon: Icons.route),
      ]);
}
