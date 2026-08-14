import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../domain/models.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search projects and services',
              ),
            ),
            const SizedBox(height: 18),
            ...items.map(
              (project) => _ProjectCard(
                project,
                services: services.valueOrNull ?? const [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.project, {required this.services});

  final ProjectModel project;
  final List<ServiceModel> services;

  @override
  Widget build(BuildContext context) {
    final own = services.where((service) => service.project == project.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DokployTheme.elevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_open, color: DokployTheme.primary),
          ),
          title: Text(
            project.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            project.description.isEmpty
                ? '${own.length} services'
                : project.description,
          ),
          children: [
            if (own.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('No services were returned for this project.'),
              ),
            ...own.map(
              (service) => ListTile(
                onTap: () => context.push('/service/${service.id}'),
                leading: StatusDot(service.status),
                title: Text(service.name),
                subtitle: Text(service.kind.name),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
