//
//  CBPeripheralViewController.m
//  CBTutorial
//
//  Created by Orlando Pereira on 10/8/13.
//  Copyright (c) 2013 Mobiletuts. All rights reserved.
//

#import "CBPeripheralViewController.h"


@implementation CBPeripheralViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    [self setupAudio];

//    NSLog(@"DATA: %i", self.musicData.length);
    
}

- (void) setupAudio {
    NSError * error;
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error != nil) {
        NSAssert(error == nil, @"");
    }
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error != nil) {
        NSAssert(error == nil, @"");
    }
    
    NSURL *soundURL = [[NSBundle mainBundle] URLForResource:@"hi" withExtension:@"m4a"];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:&error];
    if (error != nil) {
        NSAssert(error == nil, @"");
    }
    
    [self.audioPlayer setVolume:0.8];
    [self.audioPlayer prepareToPlay];
    
}
- (IBAction)playButtonPressed:(id)sender {
    NSLog(@"play button clicked");
    BOOL played = [self.audioPlayer play];
    if (!played) {
        NSLog(@"Error");
    }
    NSString * musicPath = [[NSBundle mainBundle] pathForResource:@"hi" ofType:@"m4a"];
    self.musicData = [NSData dataWithContentsOfFile:musicPath];
    _dataToSend = _musicData;
    [self sendData];
}
- (IBAction)stopButtonPressed:(id)sender {
    [self.audioPlayer stop];
}


- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID] primary:YES];
        
        transferService.characteristics = @[_transferCharacteristic];
        
        [_peripheralManager addService:transferService];
        
        [_peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] }];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    
//    _dataToSend = [_textView.text dataUsingEncoding:NSUTF8StringEncoding];
    _dataToSend = _musicData;
    
    
    _sendDataIndex = 0;

//    [self sendData];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)sendData {
    
    static BOOL sendingEOM = NO;
    
    // end of message?
    if (sendingEOM) {
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        if (didSend) {
            // It did, so mark it as sent
            sendingEOM = NO;
        }
        // didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're sending data
    // Is there any left to send?
    if (self.sendDataIndex >= self.dataToSend.length) {
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    BOOL didSend = YES;
    
    while (didSend) {
        // Work out how big it should be
        NSInteger amountToSend = self.dataToSend.length - self.sendDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.dataToSend.bytes+self.sendDataIndex length:amountToSend];
        
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        
        // It did send, so update our index
        self.sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendDataIndex >= self.dataToSend.length) {
            
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                // It sent, we're all done
                sendingEOM = NO;
                NSLog(@"Sent: EOM");
            }
            
            return;
        }
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    [self sendData];
}

@end
