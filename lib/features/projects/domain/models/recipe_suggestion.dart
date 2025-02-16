class RecipeSuggestion {
  final List<MediaAnalysis>? mediaAnalyses;
  final RecipeAnalysis? recipeAnalysis;
  final FutureSuggestions? futureSuggestions;
  final List<VideoCommand>? videoCommands;
  final String response;

  RecipeSuggestion({
    this.mediaAnalyses,
    this.recipeAnalysis,
    this.futureSuggestions,
    this.videoCommands,
    required this.response,
  });

  factory RecipeSuggestion.fromJson(Map<String, dynamic>? json) {
    if (json == null)
      return RecipeSuggestion(response: 'No response available');

    return RecipeSuggestion(
      mediaAnalyses: json['mediaAnalyses'] != null
          ? (json['mediaAnalyses'] as List)
              .map((e) => MediaAnalysis.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
      recipeAnalysis: json['recipeAnalysis'] != null
          ? RecipeAnalysis.fromJson(
              json['recipeAnalysis'] as Map<String, dynamic>?)
          : null,
      futureSuggestions: json['futureSuggestions'] != null
          ? FutureSuggestions.fromJson(
              json['futureSuggestions'] as Map<String, dynamic>?)
          : null,
      videoCommands: json['videoCommands'] != null
          ? (json['videoCommands'] as List)
              .map((e) => VideoCommand.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
      response: json['response'] as String? ?? 'No response available',
    );
  }
}

class MediaAnalysis {
  final String? id;
  final String? name;
  final String type;
  final String? url;
  final dynamic analysis;

  MediaAnalysis({
    this.id,
    this.name,
    required this.type,
    this.url,
    this.analysis,
  });

  factory MediaAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw FormatException('Null JSON provided to MediaAnalysis');
    }

    final type = json['type'] as String? ?? 'unknown';
    final analysisData = json['analysis'] as Map<String, dynamic>?;

    return MediaAnalysis(
      id: json['id'] as String?,
      name: json['name'] as String?,
      type: type,
      url: json['url'] as String?,
      analysis: analysisData != null
          ? type == 'video'
              ? VideoAnalysis.fromJson(analysisData)
              : AudioAnalysis.fromJson(analysisData)
          : null,
    );
  }
}

class VideoAnalysis {
  final List<SignificantMoment>? frameAnalysis;
  final List<SignificantMoment>? significantMoments;

  VideoAnalysis({
    this.frameAnalysis,
    this.significantMoments,
  });

  factory VideoAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VideoAnalysis();

    return VideoAnalysis(
      frameAnalysis: json['frameAnalysis'] != null
          ? (json['frameAnalysis'] as List)
              .map(
                  (e) => SignificantMoment.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
      significantMoments: json['significantMoments'] != null
          ? (json['significantMoments'] as List)
              .map(
                  (e) => SignificantMoment.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
    );
  }
}

class AudioAnalysis {
  final List<AudioSegment>? segments;
  final String? waveformUrl;

  AudioAnalysis({
    this.segments,
    this.waveformUrl,
  });

  factory AudioAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AudioAnalysis();

    return AudioAnalysis(
      segments: json['segments'] != null
          ? (json['segments'] as List)
              .map((e) => AudioSegment.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
      waveformUrl: json['waveformUrl'] as String?,
    );
  }
}

class SignificantMoment {
  final String? timestamp;
  final String? reason;

  SignificantMoment({
    this.timestamp,
    this.reason,
  });

  factory SignificantMoment.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SignificantMoment();

    return SignificantMoment(
      timestamp: json['timestamp'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class AudioSegment {
  final double? start;
  final double? end;
  final double? duration;
  final String? type;

  AudioSegment({
    this.start,
    this.end,
    this.duration,
    this.type,
  });

  factory AudioSegment.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AudioSegment();

    return AudioSegment(
      start: (json['start'] as num?)?.toDouble(),
      end: (json['end'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      type: json['type'] as String?,
    );
  }
}

class RecipeAnalysis {
  final List<TechniqueEnhancement>? suggestedEnhancements;

  RecipeAnalysis({
    this.suggestedEnhancements,
  });

  factory RecipeAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RecipeAnalysis();

    return RecipeAnalysis(
      suggestedEnhancements: json['suggestedEnhancements'] != null
          ? (json['suggestedEnhancements'] as List)
              .map((e) =>
                  TechniqueEnhancement.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
    );
  }
}

class TechniqueEnhancement {
  final String? technique;
  final String? reason;

  TechniqueEnhancement({
    this.technique,
    this.reason,
  });

  factory TechniqueEnhancement.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TechniqueEnhancement();

    return TechniqueEnhancement(
      technique: json['technique'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class FutureSuggestions {
  final List<ContentIdea>? contentIdeas;

  FutureSuggestions({
    this.contentIdeas,
  });

  factory FutureSuggestions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return FutureSuggestions();

    return FutureSuggestions(
      contentIdeas: json['contentIdeas'] != null
          ? (json['contentIdeas'] as List)
              .map((e) => ContentIdea.fromJson(e as Map<String, dynamic>?))
              .toList()
          : null,
    );
  }
}

class ContentIdea {
  final String? suggestion;

  ContentIdea({
    this.suggestion,
  });

  factory ContentIdea.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ContentIdea();

    return ContentIdea(
      suggestion: json['suggestion'] as String?,
    );
  }
}

class VideoCommand {
  final String operation;
  final String description;
  final String ffmpegCommand;
  final List<String> inputFiles;
  final String outputFile;
  final double? expectedDuration;
  final double? startTime;
  final double? endTime;
  final Map<String, dynamic>? metadata;

  VideoCommand({
    required this.operation,
    required this.description,
    required this.ffmpegCommand,
    required this.inputFiles,
    required this.outputFile,
    this.expectedDuration,
    this.startTime,
    this.endTime,
    this.metadata,
  });

  factory VideoCommand.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw FormatException('Null JSON provided to VideoCommand');
    }

    return VideoCommand(
      operation: json['operation'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      ffmpegCommand: json['ffmpegCommand'] as String? ?? '',
      inputFiles:
          (json['inputFiles'] as List?)?.map((e) => e as String).toList() ?? [],
      outputFile: json['outputFile'] as String? ?? '',
      expectedDuration: (json['expectedDuration'] as num?)?.toDouble(),
      startTime: (json['startTime'] as num?)?.toDouble(),
      endTime: (json['endTime'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
