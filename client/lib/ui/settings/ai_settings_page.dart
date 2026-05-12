import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_cloud_service.dart';
import '../../services/ai_local_agent_service.dart';
import '../../services/ai_local_service.dart';
import '../../state/app_settings.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;
  late final TextEditingController _cloudEndpointController;
  late final TextEditingController _cloudApiKeyController;
  late final TextEditingController _cloudModelController;
  late final TextEditingController _claudeCommandController;
  bool _testingLocal = false;
  bool _testingCloud = false;
  bool _testingClaude = false;
  bool _loadingModels = false;
  String? _modelsError;
  List<String> _availableModels = const [];
  AiProviderType? _lastProvider;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<AppSettings>(context, listen: false);
    _endpointController = TextEditingController(text: settings.aiLocalEndpoint);
    _modelController = TextEditingController(text: settings.aiLocalModel);
    _cloudEndpointController =
        TextEditingController(text: settings.aiCloudEndpoint);
    _cloudApiKeyController =
        TextEditingController(text: settings.aiCloudApiKey);
    _cloudModelController = TextEditingController(text: settings.aiCloudModel);
    _claudeCommandController =
        TextEditingController(text: settings.aiClaudeCommand);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<AppSettings>(context);
    if (settings.aiProvider == AiProviderType.local &&
        _lastProvider != AiProviderType.local) {
      _lastProvider = AiProviderType.local;
      _loadModels();
    } else if (settings.aiProvider != _lastProvider) {
      _lastProvider = settings.aiProvider;
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _cloudEndpointController.dispose();
    _cloudApiKeyController.dispose();
    _cloudModelController.dispose();
    _claudeCommandController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    if (_loadingModels) return;
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });

    final l = AppLocalizations.of(context);
    final service = Provider.of<AiLocalService>(context, listen: false);
    try {
      final models = await service.fetchAvailableModels();
      if (!mounted) return;
      setState(() {
        _availableModels = models;
      });
      final settings = Provider.of<AppSettings>(context, listen: false);
      if (settings.aiLocalModel.trim().isEmpty && models.isNotEmpty) {
        await settings.setAiLocalModel(models.first);
        _modelController.text = models.first;
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _modelsError = error.message == 'missing_config'
            ? l.aiLocalEndpointMissing
            : l.aiLocalModelsFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _modelsError = l.aiLocalModelsFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingModels = false;
        });
      }
    }
  }

  Future<void> _testLocalModel() async {
    if (_testingLocal) return;
    setState(() {
      _testingLocal = true;
    });

    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context, listen: false);
    final service = Provider.of<AiLocalService>(context, listen: false);

    try {
      final available = await service.checkModelAvailable();
      if (!mounted) return;
      final message = available
          ? l.aiLocalTestSuccess
          : l.aiLocalTestModelMissing(settings.aiLocalModel);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      final message = error.message == 'missing_config'
          ? l.aiLocalConfigMissing
          : l.aiLocalTestFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiLocalTestFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _testingLocal = false;
        });
      }
    }
  }

  Future<void> _testCloudModel() async {
    if (_testingCloud) return;
    setState(() {
      _testingCloud = true;
    });

    final l = AppLocalizations.of(context);
    final service = Provider.of<AiCloudService>(context, listen: false);

    try {
      await service.testConnection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiCloudTestSuccess)),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      final message = error.message == 'missing_config'
          ? l.aiCloudConfigMissing
          : error.message.isNotEmpty
              ? l.aiCloudTestFailedWithReasonText(error.message)
              : l.aiCloudTestFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiCloudTestFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _testingCloud = false;
        });
      }
    }
  }

  Future<void> _testClaudeCode() async {
    if (_testingClaude) return;
    setState(() {
      _testingClaude = true;
    });

    try {
      final l = AppLocalizations.of(context);
      final service = Provider.of<AiLocalAgentService>(context, listen: false);
      await service.testClaudeCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiClaudeTestSuccess)),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final message = error.message == 'missing_config'
          ? l.aiClaudeConfigMissing
          : l.aiClaudeTestFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiClaudeTestFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _testingClaude = false;
        });
      }
    }
  }

  Widget _buildModelList(AppSettings settings) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (_loadingModels) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(l.aiLocalModelsLoading, style: theme.textTheme.bodySmall),
        ],
      );
    }

    if (_modelsError != null) {
      return Text(
        _modelsError!,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red[600]),
      );
    }

    if (_availableModels.isEmpty) {
      return Text(
        l.aiLocalModelsEmpty,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final model in _availableModels)
          ChoiceChip(
            label: Text(model),
            selected: settings.aiLocalModel == model,
            onSelected: (_) {
              settings.setAiLocalModel(model);
              _modelController.text = model;
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.aiSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l.aiSettingsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(l.aiProvider, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                RadioListTile<AiProviderType>(
                  value: AiProviderType.local,
                  groupValue: settings.aiProvider,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setAiProvider(value);
                    }
                  },
                  title: Text(l.aiProviderLocal),
                  subtitle: Text(l.aiProviderLocalHint),
                ),
                const Divider(height: 1),
                RadioListTile<AiProviderType>(
                  value: AiProviderType.cloud,
                  groupValue: settings.aiProvider,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setAiProvider(value);
                    }
                  },
                  title: Text(l.aiProviderCloud),
                  subtitle: Text(l.aiProviderCloudHint),
                ),
                const Divider(height: 1),
                RadioListTile<AiProviderType>(
                  value: AiProviderType.claudeCode,
                  groupValue: settings.aiProvider,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setAiProvider(value);
                    }
                  },
                  title: Text(l.aiProviderClaudeCode),
                  subtitle: Text(l.aiProviderClaudeCodeHint),
                ),
              ],
            ),
          ),
          if (settings.aiProvider == AiProviderType.local) ...[
            const SizedBox(height: 16),
            Text(l.aiLocalSettings, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.aiLocalEndpoint,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: TextField(
                      controller: _endpointController,
                      decoration: InputDecoration(
                        hintText: l.aiLocalEndpointHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        settings.setAiLocalEndpoint(value);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.aiLocalModel,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: TextField(
                      controller: _modelController,
                      decoration: InputDecoration(
                        hintText: l.aiLocalModelHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        settings.setAiLocalModel(value);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.aiLocalModelsTitle,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _loadingModels ? null : _loadModels,
                          child: Text(l.aiLocalModelsRefresh),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildModelList(settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testingLocal ? null : _testLocalModel,
                icon: const Icon(Icons.bolt_outlined),
                label: Text(_testingLocal ? l.aiLocalTesting : l.aiLocalTest),
              ),
            ),
          ],
          if (settings.aiProvider == AiProviderType.cloud) ...[
            const SizedBox(height: 16),
            Text(l.aiCloudSettings, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.aiCloudEndpoint,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: TextField(
                      controller: _cloudEndpointController,
                      decoration: InputDecoration(
                        hintText: l.aiCloudEndpointHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        settings.setAiCloudEndpoint(value);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.aiCloudApiKey,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: TextField(
                      controller: _cloudApiKeyController,
                      decoration: InputDecoration(
                        hintText: l.aiCloudApiKeyHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _showApiKey = !_showApiKey;
                            });
                          },
                          icon: Icon(_showApiKey
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      obscureText: !_showApiKey,
                      enableSuggestions: false,
                      autocorrect: false,
                      onChanged: (value) {
                        settings.setAiCloudApiKey(value);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.aiCloudModel,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: TextField(
                      controller: _cloudModelController,
                      decoration: InputDecoration(
                        hintText: l.aiCloudModelHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        settings.setAiCloudModel(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testingCloud ? null : _testCloudModel,
                icon: const Icon(Icons.cloud_outlined),
                label: Text(_testingCloud ? l.aiCloudTesting : l.aiCloudTest),
              ),
            ),
          ],
          if (settings.aiProvider == AiProviderType.claudeCode) ...[
            const SizedBox(height: 16),
            Text(l.aiClaudeSettings, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.aiClaudeCommand,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: TextField(
                      controller: _claudeCommandController,
                      decoration: InputDecoration(
                        hintText: l.aiClaudeCommandHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        settings.setAiClaudeCommand(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testingClaude ? null : _testClaudeCode,
                icon: const Icon(Icons.terminal_outlined),
                label: Text(
                  _testingClaude ? l.aiClaudeTesting : l.aiClaudeTest,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l.aiProviderFootnote,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
