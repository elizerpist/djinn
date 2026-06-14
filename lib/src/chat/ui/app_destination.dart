import 'package:flutter/material.dart';

enum AppDestinationId { notes, knowledge, chat, search, settings }

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
    id: AppDestinationId.notes,
    label: 'Jegyzetek',
    compactLabel: 'Jegyzetek',
    icon: Icons.edit_note_outlined,
  ),
  AppDestination(
    id: AppDestinationId.knowledge,
    label: 'Tudástár',
    compactLabel: 'Tudástár',
    icon: Icons.folder_outlined,
  ),
  AppDestination(
    id: AppDestinationId.chat,
    label: 'Chat',
    compactLabel: 'Chat',
    icon: Icons.chat_bubble_outline,
  ),
  AppDestination(
    id: AppDestinationId.search,
    label: 'Keresés',
    compactLabel: 'Keresés',
    icon: Icons.search,
  ),
  AppDestination(
    id: AppDestinationId.settings,
    label: 'Beállítások',
    compactLabel: 'Beáll.',
    icon: Icons.settings_outlined,
  ),
];
