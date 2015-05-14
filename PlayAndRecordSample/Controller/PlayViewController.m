//
//  ViewController.m
//  PlayAndRecordSample
//
//  Created by Vladimir Kravchenko on 5/12/15.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "PlayViewController.h"
#import "AERecorder.h"
#import "AEAudioUnitFilePlayer.h"
#import "Track.h"
#import "TrackCell.h"

static const NSInteger kSecInMinute = 60;
static const NSInteger kMillesimalMultiplier = 1000;
static const CGFloat kUpdateInterval = 0.2;

@interface PlayViewController () <UITableViewDelegate, UITableViewDataSource>

@property(weak, nonatomic) IBOutlet UILabel *secondsLabel;
@property(weak, nonatomic) IBOutlet UILabel *milliSecondsLabel;
@property(weak, nonatomic) IBOutlet UILabel *durationLabel;
@property(weak, nonatomic) IBOutlet UISlider *progressSlider;
@property(weak, nonatomic) IBOutlet UIButton *playButton;
@property(weak, nonatomic) IBOutlet UIButton *recButton;
@property(weak, nonatomic) IBOutlet UITableView *tableView;
@property(strong, nonatomic) NSMutableArray *tracks;
@property(strong, nonatomic) NSMutableArray *players;
@property(strong, nonatomic) AEAudioUnitFilePlayer *playerWithMaxDuration;
@property(assign, nonatomic) BOOL isPlaying;
@property(strong, nonatomic) AERecorder *recorder;
@property(strong, nonatomic) AEAudioController *audioController;
@property(strong, nonatomic) NSTimer *progressUpdateTimer;
@end

@implementation PlayViewController

- (void)dealloc {

}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tracks = [NSMutableArray new];
    self.players = [NSMutableArray new];
    [self preLoadTracks];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setupAudioController];
    [self setupPlayers];
}

#pragma mark - Tracks

- (void)preLoadTracks {
    NSURL *urlForMetronome = [[NSBundle mainBundle] URLForResource:@"metronome"
                                                     withExtension:@"mp3"];
    for (int i = 0; i < 5; i++) {
        NSString *name = [NSString stringWithFormat:@"Metronome %i", i];
        Track *track = [Track trackWithName:name urlString:[urlForMetronome absoluteString]];
        [self.tracks addObject:track];
    }
}

#pragma mark - Audio controller

- (void)setupAudioController {
    AudioStreamBasicDescription description =
        [AEAudioController nonInterleaved16BitStereoAudioDescription];
    self.audioController = [[AEAudioController alloc] initWithAudioDescription:description
                                                                  inputEnabled:YES];
    _audioController.preferredBufferDuration = 0.005;
    _audioController.useMeasurementMode = YES;
    [_audioController start:nil];
}

#pragma mark - Players

- (void)setupPlayers {
    [self.tracks enumerateObjectsUsingBlock:^(Track *track, NSUInteger idx, BOOL *stop) {
        [self addPlayerForTrack:track];
    }];
}

- (void)addPlayerForTrack:(Track *)track {
    if (!track.urlString.length)
        return;
    NSURL *fileURL = [NSURL URLWithString:track.urlString];
    NSError *error = nil;
    AEAudioUnitFilePlayer *player;
    player = [AEAudioUnitFilePlayer audioUnitFilePlayerWithController:self.audioController
                                                                error:&error];
    if (player) {
        [self.audioController addChannels:@[player]];
        [player setUrl:fileURL];
        [self.players addObject:player];
        if (player.duration > self.playerWithMaxDuration.duration) {
            self.playerWithMaxDuration = player;
            [self updateProgressViewsWithDuration:player.duration];
        }
    }
    else {
        NSLog(@"Can not create player: %@", error);
    }
}

- (AEAudioUnitFilePlayer *)playerForTrack:(Track *)track {
    return self.players[[self.tracks indexOfObject:track]];
}

#pragma mark - IBActions

- (IBAction)playButtonPressed:(id)sender {
    if (self.isPlaying) {
        if (self.recorder)
            [self save];
        else
            [self stopSynchronouslyWithMessageBlock:nil completion:nil];
    }
    else
        [self playSynchronouslyWithMessageBlock:nil completion:nil];
}

- (IBAction)recButtonPressed:(id)sender {
    if (self.recorder)
        [self save];
    else
        [self record];
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    if (self.recorder)
        [self save];
    else {
        __weak typeof(self) weakSelf = self;
        [self stopSynchronouslyWithMessageBlock:nil
                                     completion:^{
                                         [weakSelf.playerWithMaxDuration setCurrentTime:sender.value];
                                     }];
    }
    [self updateProgressViewsWithTime:sender.value];
}

#pragma mark - Interface

- (void)updatePlayButtonTitle {
    if (self.isPlaying)
        [self.playButton setTitle:@"STOP" forState:UIControlStateNormal];
    else
        [self.playButton setTitle:@"PLAY" forState:UIControlStateNormal];
}

- (void)updateRecButtonTitle {
    if (self.recorder)
        [self.recButton setTitle:@"SAVE" forState:UIControlStateNormal];
    else
        [self.recButton setTitle:@"REC" forState:UIControlStateNormal];
}

- (void)updateProgressViewsWithDuration:(NSTimeInterval)duration {
    [self.progressSlider setMaximumValue:(float) duration];
    [self.durationLabel setText:[self timeStringWithInterval:duration]];
}

- (void)updateProgressViewsWithTime:(NSTimeInterval)time {
    if (time < 0 || !isnormal(time))
        time = 0;
    if (!self.progressSlider.isHighlighted)
        [self.progressSlider setValue:(float) time];
    [self updateTimeLabelsWithTime:time];
}

- (void)updateTimeLabelsWithTime:(NSTimeInterval)time {
    NSTimeInterval integralTime;
    NSTimeInterval fractionalTime = modf(time, &integralTime) * kMillesimalMultiplier;
    [self.milliSecondsLabel setText:[NSString stringWithFormat:@".%.0f", fractionalTime]];
    [self.secondsLabel setText:[self timeStringWithInterval:integralTime]];
}

- (NSString *)timeStringWithInterval:(NSTimeInterval)interval {
    return [NSString stringWithFormat:
        @"%li:%02li", (long) interval / kSecInMinute, (long) interval % kSecInMinute];
}

#pragma mark - Play

- (void)playSynchronouslyWithMessageBlock:(dispatch_block_t)messageBlock
                               completion:(dispatch_block_t)completionBlock {
    self.isPlaying = YES;
    [self updatePlayButtonTitle];
    [self.players enumerateObjectsUsingBlock:
        ^(AEAudioUnitFilePlayer *player, NSUInteger idx, BOOL *stop) {
            [player setCurrentTime:self.playerWithMaxDuration.currentTime];
        }];
    CFMutableArrayRef players = (__bridge CFMutableArrayRef) self.players;
    __weak typeof(self) weakSelf = self;
    [self.audioController
        performAsynchronousMessageExchangeWithBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            for (CFIndex i = 0; i < CFArrayGetCount(players); i++) {
                AEAudioUnitFilePlayer *player =
                    (AEAudioUnitFilePlayer *) CFArrayGetValueAtIndex(players, i);
                AEAudioUnitFilePlayerPlayWithAudioController(player, strongSelf->_audioController);
            }
            if (messageBlock)
                messageBlock();
        }
                                      responseBlock:^{
                                          if (completionBlock)
                                              completionBlock();
                                      }];
    if (![self.progressUpdateTimer isValid])
        [self addProgressUpdateTimer];
}

#pragma mark - Timer

- (void)addProgressUpdateTimer {
    self.progressUpdateTimer = [NSTimer timerWithTimeInterval:kUpdateInterval
                                                       target:self
                                                     selector:@selector(updatePlaybackProgress)
                                                     userInfo:nil
                                                      repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.progressUpdateTimer forMode:NSRunLoopCommonModes];
}

- (void)updatePlaybackProgress {
    if (self.progressSlider.isTracking)
        return;
    NSTimeInterval currentTime = self.playerWithMaxDuration.currentTime;
    [self updateProgressViewsWithTime:currentTime];
//    if (currentTime == 0)
//        [self stop];
}

#pragma mark - Stop

- (void)stopSynchronouslyWithMessageBlock:(dispatch_block_t)messageBlock
                               completion:(dispatch_block_t)completionBlock {
    self.isPlaying = NO;
    [self updatePlayButtonTitle];
    CFMutableArrayRef players = (__bridge CFMutableArrayRef) self.players;
    __weak typeof(self) weakSelf = self;
    [self.audioController
        performAsynchronousMessageExchangeWithBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (messageBlock)
                messageBlock();
            for (CFIndex i = 0; i < CFArrayGetCount(players); i++) {
                AEAudioUnitFilePlayer *player =
                    (AEAudioUnitFilePlayer *) CFArrayGetValueAtIndex(players, i);
                AEAudioUnitFilePlayerStopInAudioController(player, strongSelf->_audioController);
            }
        }
                                      responseBlock:^{
                                          if (completionBlock)
                                              completionBlock();
                                          [self.progressUpdateTimer invalidate];
                                      }];
}

#pragma mark - Record

- (void)record {
    NSString *path = [self pathForNewRecordFile];
    [self prepareRecorderWithPath:path];
    [self updateRecButtonTitle];
    __weak typeof(self) weakSelf = self;
    [self playSynchronouslyWithMessageBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            AERecorderStartRecording(strongSelf->_recorder);
        }
                                 completion:nil];
}

- (NSString *)pathForNewRecordFile {
    NSArray *cachesFolders =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *fileName = [NSString stringWithFormat:@"Rec_%@.m4a", [[NSUUID UUID] UUIDString]];
    NSString *path = [cachesFolders[0] stringByAppendingPathComponent:fileName];
    return path;
}

- (void)prepareRecorderWithPath:(NSString *)path {
    if (!path.length)
        return;
    if (self.recorder)
        return;
    self.recorder = [[AERecorder alloc] initWithAudioController:self.audioController];
    NSError *error = nil;
    if (![self.recorder prepareRecordingToFileAtPath:path
                                            fileType:kAudioFileM4AType
                                               error:&error]) {
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:[NSString stringWithFormat:
                                        @"Couldn't start recording: %@",
                                        [error localizedDescription]]
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        self.recorder = nil;
        return;
    }
    [self.audioController addInputReceiver:self.recorder];
}

#pragma mark - Save

- (void)save {
    __weak typeof(self) weakSelf = self;
    [self stopSynchronouslyWithMessageBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            AERecorderStopRecording(strongSelf->_recorder);
        }
                                 completion:^{
                                     [weakSelf finishRecordAndSaveTrack];
                                 }];
}

- (void)finishRecordAndSaveTrack {
    [self.recorder finishRecording];
    [self.audioController removeInputReceiver:self.recorder];
    NSURL *fileURL = [NSURL fileURLWithPath:self.recorder.path];
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];
    AVMutableCompositionTrack *compositionTrack;
    compositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    NSArray *assetTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *assetTrack = [assetTracks firstObject];
    NSTimeInterval trackDuration = CMTimeGetSeconds(asset.duration);
    NSTimeInterval trackStartTime = self.playerWithMaxDuration.currentTime - trackDuration;
    [self insertEmptyTimeToCompositionTrack:compositionTrack
                              withStartTime:0
                                andDuration:trackStartTime];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, asset.duration);
    CMTime startTime = CMTimeMakeWithSeconds(trackStartTime, NSEC_PER_SEC);
    NSError *error = nil;
    BOOL success = [compositionTrack insertTimeRange:timeRangeInAsset
                                             ofTrack:assetTrack
                                              atTime:startTime
                                               error:&error];
    if (!success)
        NSLog(@"Insert Track Error: %@", error);
    if ([self validateCompositionTrack:compositionTrack]) {
        __weak typeof(self) weakSelf = self;
        [self saveComposition:composition
                  withSuccess:^(NSString *filePath, NSTimeInterval duration){
                      [weakSelf saveTrackWithFilePath:filePath duration:duration];
                      weakSelf.recorder = nil;
                      [weakSelf updateRecButtonTitle];
                  }
                      failure:^(NSString *errorMessage){
                          [[[UIAlertView alloc] initWithTitle:@""
                                                      message:errorMessage
                                                     delegate:nil
                                            cancelButtonTitle:@"Ok"
                                            otherButtonTitles:nil] show];
                      }];
    }
}

- (void)saveTrackWithFilePath:(NSString *)filePath duration:(NSTimeInterval)duration {
    Track *track = [Track trackWithName:filePath.lastPathComponent
                              urlString:filePath];
    [self.tracks addObject:track];
    [self addPlayerForTrack:track];
    [self.tableView reloadData];
}

- (void)insertEmptyTimeToCompositionTrack:(AVMutableCompositionTrack *)compositionTrack
                            withStartTime:(NSTimeInterval)startTime
                              andDuration:(NSTimeInterval)duration {
    CMTime emptyStartTime = CMTimeMakeWithSeconds(startTime, NSEC_PER_SEC);
    CMTime emptyDuration = CMTimeMakeWithSeconds(duration, NSEC_PER_SEC);
    [compositionTrack insertEmptyTimeRange:CMTimeRangeMake(emptyStartTime, emptyDuration)];
}

- (BOOL)validateCompositionTrack:(AVMutableCompositionTrack *)compositionAudioTrack {
    NSError *error = nil;
    if (![compositionAudioTrack validateTrackSegments:compositionAudioTrack.segments
                                                error:&error]) {
        NSLog(@"Track segmants are invalid: %@", error.localizedDescription);
        return NO;
    }
    return YES;
}

- (void)saveComposition:(AVMutableComposition *)composition
            withSuccess:(void (^)(NSString *filePath, NSTimeInterval duration))successBlock
                failure:(void (^)(NSString *errorMessage))failureBlock {
    AVAssetExportSession *exportSession;
    exportSession = [AVAssetExportSession exportSessionWithAsset:composition
                                                      presetName:AVAssetExportPresetAppleM4A];
    if (nil == exportSession) {
        if (failureBlock)
            failureBlock(@"Can not create export session");
        return;
    }
    NSString *cachesDirectory =
        NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSString *lastPathComponent =
        [NSString stringWithFormat:@"%@.m4a", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [cachesDirectory stringByAppendingPathComponent:lastPathComponent];
    NSLog(@"Output file path - %@", filePath);
    exportSession.outputURL = [NSURL fileURLWithPath:filePath];
    exportSession.outputFileType = AVFileTypeAppleM4A;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (AVAssetExportSessionStatusCompleted == exportSession.status) {
            NSLog(@"AVAssetExportSessionStatusCompleted");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (successBlock)
                    successBlock(filePath, CMTimeGetSeconds(composition.duration));
            });
        }
        else {
            NSString *errorMessage = nil;
            if (AVAssetExportSessionStatusFailed == exportSession.status)
                errorMessage = @"Failed to write file";
            NSLog(@"Export Session Status: %ld", (long) exportSession.status);
            if (failureBlock)
                failureBlock(errorMessage);
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TrackCell"
                                                      forIndexPath:indexPath];
    Track *track = self.tracks[(NSUInteger) indexPath.row];
    [cell.nameLabel setText:track.name];
    [cell setMuteBlock:^(TrackCell *aCell) {
        [self muteActionForCell:aCell];
    }];
    return cell;
}

- (void)muteActionForCell:(TrackCell *)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    Track *track = self.tracks[(NSUInteger) indexPath.row];
    AEAudioUnitFilePlayer *player = [self playerForTrack:track];
    if (player) {
        player.volume = player.volume > 0 ? 0 : 1;
        NSString *title = player.volume > 0 ? @"MUTE" : @"UNMUTE";
        [cell.muteButton setTitle:title forState:UIControlStateNormal];
    }
    else
        NSLog(@"No player was found for cell at %li row", (long) indexPath.row);
}

@end
