import 'package:flutter/material.dart';

enum AppDestinationId { cases, flow, chat, knowledge, settings }

class AppDestination {
  const AppDestination({
    required this.id,
    required this.label,
    required this.compactLabel,
    required this.icon,
  });

  final AppDestinationId id;
  final String label;
  final String compactLabel;
  final IconData icon;
}

const appDestinations = [
  AppDestination(
    id: AppDestinationId.cases,
    label: 'Esetek',
    compactLabel: 'Esetek',
    icon: Icons.assignment_outlined,
  ),
  AppDestination(
    id: AppDestinationId.flow,
    label: 'Audit',
    compactLabel: 'Audit',
    icon: Icons.fact_check_outlined,
  ),
  AppDestination(
    id: AppDestinationId.chat,
    label: 'Chat',
    compactLabel: 'Chat',
    icon: Icons.chat_bubble_outline,
  ),
  AppDestination(
    id: AppDestinationId.knowledge,
    label: 'Tudástár',
    compactLabel: 'Tudástár',
    icon: Icons.folder_outlined,
  ),
  AppDestination(
    id: AppDestinationId.settings,
    label: 'Beállítások',
    compactLabel: 'Beáll.',
    icon: Icons.settings_outlined,
  ),
];
