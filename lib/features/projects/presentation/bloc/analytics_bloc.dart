import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/entities/analytics_data_point.dart';

// Events
abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadAnalytics extends AnalyticsEvent {
  final String projectId;

  const LoadAnalytics(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class UpdateDateRange extends AnalyticsEvent {
  final DateTime startDate;
  final DateTime endDate;

  const UpdateDateRange({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

// States
enum AnalyticsStatus { initial, loading, success, error }

class AnalyticsState extends Equatable {
  final AnalyticsStatus status;
  final String? error;
  final String? projectId;
  final int totalViews;
  final double engagementRate;
  final double viewsChange;
  final double engagementChange;
  final List<AnalyticsDataPoint> viewsData;
  final List<AnalyticsDataPoint> retentionData;
  final Duration averageWatchTime;
  final Duration totalWatchTime;
  final int uniqueViewers;
  final int peakConcurrentViewers;
  final DateTime? startDate;
  final DateTime? endDate;

  const AnalyticsState({
    this.status = AnalyticsStatus.initial,
    this.error,
    this.projectId,
    this.totalViews = 0,
    this.engagementRate = 0.0,
    this.viewsChange = 0.0,
    this.engagementChange = 0.0,
    this.viewsData = const [],
    this.retentionData = const [],
    this.averageWatchTime = const Duration(),
    this.totalWatchTime = const Duration(),
    this.uniqueViewers = 0,
    this.peakConcurrentViewers = 0,
    this.startDate,
    this.endDate,
  });

  AnalyticsState copyWith({
    AnalyticsStatus? status,
    String? error,
    String? projectId,
    int? totalViews,
    double? engagementRate,
    double? viewsChange,
    double? engagementChange,
    List<AnalyticsDataPoint>? viewsData,
    List<AnalyticsDataPoint>? retentionData,
    Duration? averageWatchTime,
    Duration? totalWatchTime,
    int? uniqueViewers,
    int? peakConcurrentViewers,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      error: error,
      projectId: projectId ?? this.projectId,
      totalViews: totalViews ?? this.totalViews,
      engagementRate: engagementRate ?? this.engagementRate,
      viewsChange: viewsChange ?? this.viewsChange,
      engagementChange: engagementChange ?? this.engagementChange,
      viewsData: viewsData ?? this.viewsData,
      retentionData: retentionData ?? this.retentionData,
      averageWatchTime: averageWatchTime ?? this.averageWatchTime,
      totalWatchTime: totalWatchTime ?? this.totalWatchTime,
      uniqueViewers: uniqueViewers ?? this.uniqueViewers,
      peakConcurrentViewers:
          peakConcurrentViewers ?? this.peakConcurrentViewers,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  List<Object?> get props => [
        status,
        error,
        projectId,
        totalViews,
        engagementRate,
        viewsChange,
        engagementChange,
        viewsData,
        retentionData,
        averageWatchTime,
        totalWatchTime,
        uniqueViewers,
        peakConcurrentViewers,
        startDate,
        endDate,
      ];
}

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final AnalyticsRepository _analyticsRepository;

  AnalyticsBloc({
    required AnalyticsRepository analyticsRepository,
  })  : _analyticsRepository = analyticsRepository,
        super(const AnalyticsState()) {
    on<LoadAnalytics>(_onLoadAnalytics);
    on<UpdateDateRange>(_onUpdateDateRange);
  }

  Future<void> _onLoadAnalytics(
    LoadAnalytics event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(
      status: AnalyticsStatus.loading,
      projectId: event.projectId,
    ));

    try {
      final analytics = await _analyticsRepository.getProjectAnalytics(
        event.projectId,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      emit(state.copyWith(
        status: AnalyticsStatus.success,
        totalViews: analytics.totalViews,
        engagementRate: analytics.engagementRate,
        viewsChange: analytics.viewsChange,
        engagementChange: analytics.engagementChange,
        viewsData: analytics.viewsData,
        retentionData: analytics.retentionData,
        averageWatchTime: analytics.averageWatchTime,
        totalWatchTime: analytics.totalWatchTime,
        uniqueViewers: analytics.uniqueViewers,
        peakConcurrentViewers: analytics.peakConcurrentViewers,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AnalyticsStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateDateRange(
    UpdateDateRange event,
    Emitter<AnalyticsState> emit,
  ) async {
    emit(state.copyWith(
      startDate: event.startDate,
      endDate: event.endDate,
    ));

    add(LoadAnalytics(state.projectId!));
  }
}
