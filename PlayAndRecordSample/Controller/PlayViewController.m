//
//  ViewController.m
//  PlayAndRecordSample
//
//  Created by Vladimir Kravchenko on 5/12/15.
//  Copyright (c) 2015 A Tasty Pixel. All rights reserved.
//

#import "PlayViewController.h"
#import "AERecorder.h"
#import "AEAudioUnitFilePlayer.h"
#import "Track.h"

static const NSInteger kSecInMinute = 60;
static const NSInteger kMillesimalMultiplier = 1000;
static const CGFloat kUpdateInterval = 0.2;

@interface PlayViewController () <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UILabel *secondsLabel;
@property (weak, nonatomic) IBOutlet UILabel *milliSecondsLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *recButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableArray *tracks;
@property (strong, nonatomic) NSMutableArray *players;
@property (strong, nonatomic) AEAudioUnitFilePlayer *playerWithMaxDuration;
@property (assign, nonatomic) BOOL isPlaying;
@property (strong, nonatomic) AERecorder *recorder;
@property (strong, nonatomic) AEAudioController *audioController;
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

#pragma mark - Preload tracks

- (void)preLoadTracks {
    NSURL *urlForMetronome = [[NSBundle mainBundle] URLForResource:@"metronome"
                                                     withExtension:@"mp3"];
    Track *track1 = [Track trackWithName:@"Metronome 1" urlString:[urlForMetronome absoluteString]];
    Track *track2= [Track trackWithName:@"Metronome 2" urlString:[urlForMetronome absoluteString]];
    [self.tracks addObject:track1];
    [self.tracks addObject:track2];
}

#pragma mark - Setup audio controller

- (void)setupAudioController {
    AudioStreamBasicDescription description =
        [AEAudioController nonInterleaved16BitStereoAudioDescription];
    self.audioController = [[AEAudioController alloc] initWithAudioDescription:description
                                                                  inputEnabled:YES];
    _audioController.preferredBufferDuration = 0.005;
    _audioController.useMeasurementMode = YES;
    [_audioController start:NULL];
}

#pragma mark - Setup players

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

#pragma mark - IBActions

- (IBAction)playButtonPressed:(id)sender {
    if (self.isPlaying)
        [self stop];
    else
        [self play];
    self.isPlaying = !self.isPlaying;
    [self updatePlayButtonTitle];
}

- (IBAction)recButtonPressed:(id)sender {
    if (self.recorder)
        [self save];
    else
        [self record];
    [self updateRecButtonTitle];
}

- (IBAction)sliderValueChanged:(id)sender {
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

- (void)play {
    [self.players enumerateObjectsUsingBlock:
        ^(AEAudioUnitFilePlayer *player, NSUInteger idx, BOOL *stop) {
            [player setCurrentTime:self.playerWithMaxDuration.currentTime];
            player.playing = YES;
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

- (void)stop {
    [self.players enumerateObjectsUsingBlock:
        ^(AEAudioUnitFilePlayer *player, NSUInteger idx, BOOL *stop) {
            player.playing = NO;
        }];
}

#pragma mark - Record

- (void)record {

}

#pragma mark - Save

- (void)save {

}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}


@end