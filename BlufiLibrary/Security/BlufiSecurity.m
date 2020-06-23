//
//  BlufiSecurity.m
//  EspBlufi
//
//  Created by AE on 2020/6/9.
//  Copyright © 2020 espressif. All rights reserved.
//

#import "BlufiSecurity.h"
#import <CommonCrypto/CommonCrypto.h>
#import <openssl/rsa.h>
#import <openssl/pem.h>
#import <openssl/dh.h>
#import <openssl/bn.h>

// Should make these numbers massive to be more secure
// Bigger the number the slower the algorithm
#define MAX_RANDOM_NUMBER 2147483648
#define MAX_PRIME_NUMBER   2147483648

// Linear Feedback Shift Registers
#define LFSR(n)    {if (n&1) n=((n^0x80000055)>>1)|0x80000000; else n>>=1;}

// Rotate32
#define ROT(x, y)  (x=(x<<y)|(x>>(32-y)))

@implementation BlufiSecurity

const NSInteger CRC_TB[] = {
        0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7, 0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
        0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6, 0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
        0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485, 0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
        0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4, 0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
        0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823, 0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
        0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12, 0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
        0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41, 0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
        0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70, 0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
        0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f, 0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
        0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e, 0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
        0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d, 0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
        0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c, 0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
        0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab, 0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
        0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a, 0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
        0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9, 0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
        0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8, 0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0
};

const Byte DH_P[] = {
    0xcf,0x5c,0xf5,0xc3,0x84,0x19,0xa7,0x24,0x95,0x7f,0xf5,0xdd,0x32,0x3b,0x9c,0x45,0xc3,0xcd,0xd2,0x61,0xeb,0x74,0x0f,0x69,0xaa,0x94,0xb8,0xbb,0x1a,0x5c,0x96,0x40,0x91,0x53,0xbd,0x76,0xb2,0x42,0x22,0xd0,0x32,0x74,0xe4,0x72,0x5a,0x54,0x06,0x09,0x2e,0x9e,0x82,0xe9,0x13,0x5c,0x64,0x3c,0xae,0x98,0x13,0x2b,0x0d,0x95,0xf7,0xd6,0x53,0x47,0xc6,0x8a,0xfc,0x1e,0x67,0x7d,0xa9,0x0e,0x51,0xbb,0xab,0x5f,0x5c,0xf4,0x29,0xc2,0x91,0xb4,0xba,0x39,0xc6,0xb2,0xdc,0x5e,0x8c,0x72,0x31,0xe4,0x6a,0xa7,0x72,0x8e,0x87,0x66,0x45,0x32,0xcd,0xf5,0x47,0xbe,0x20,0xc9,0xa3,0xfa,0x83,0x42,0xbe,0x6e,0x34,0x37,0x1a,0x27,0xc0,0x6f,0x7d,0xc0,0xed,0xdd,0xd2,0xf8,0x63,0x73
};
const BN_ULONG DH_G = 2;

+ (NSInteger)crc:(NSInteger)crc data:(NSData *)data {
    Byte *buf = (Byte *)data.bytes;
    return [BlufiSecurity crc:crc buf:buf length:data.length];
}

+ (NSInteger)crc:(NSInteger)crc buf:(Byte *)buf length:(NSInteger)length {
    crc = (~crc) & 0xffff;
    for (NSInteger i = 0; i < length; ++i) {
        Byte b = buf[i];
        crc = CRC_TB[(crc >> 8) ^ b] ^ (crc << 8);
        crc &= 0xffff;
    }
    return (~crc) & 0xffff;
}

+ (NSData *)md5:(NSData *)data {
    Byte *buf = (Byte *)data.bytes;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(buf, (CC_LONG)data.length, digest);
    Byte resultBuf[CC_MD5_DIGEST_LENGTH];
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
        resultBuf[i] = (Byte)digest[i];
    }
    return [NSData dataWithBytes:resultBuf length:CC_MD5_DIGEST_LENGTH];
}

+ (NSData *)aecCrypt:(NSData *)originData cryptor:(CCCryptorRef)cryptor {
    NSUInteger inputLength = originData.length;
    char *outData = malloc(inputLength);
    memset(outData, 0, inputLength);
    
    size_t outLength = 0;
    CCCryptorUpdate(cryptor, originData.bytes, inputLength, outData, inputLength, &outLength);
    NSData *resultData = [NSData dataWithBytes:outData length:outLength];
    
    CCCryptorRelease(cryptor);
    free(outData);
    
    return resultData;
}

+ (NSData *)aesEncrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv {
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = CCCryptorCreateWithMode(kCCEncrypt, kCCModeCFB, kCCAlgorithmAES, ccNoPadding, iv.bytes, key.bytes, key.length, NULL, 0, 0, 0, &cryptor);
    if (status != kCCSuccess) {
        NSLog(@"BlufiSecurity aesEncrypt error: %@", @(status));
        return nil;
    }
    return [self aecCrypt:data cryptor:cryptor];
}

+ (NSData *)aesDecrypt:(NSData *)data key:(NSData *)key iv:(NSData *)iv {
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = CCCryptorCreateWithMode(kCCDecrypt, kCCModeCFB, kCCAlgorithmAES, ccNoPadding, iv.bytes, key.bytes, key.length, NULL, 0, 0, 0, &cryptor);
    if (status != kCCSuccess) {
        NSLog(@"BlufiSecurity aesEncrypt error: %@", @(status));
        return nil;
    }
    return [self aecCrypt:data cryptor:cryptor];
}

+ (BlufiDH *)dhGenerateKeys {
    DH *dh;
    int ret = 0, i;
    dh = DH_new();
    
    dh->p = BN_bin2bn(DH_P, sizeof(DH_P), NULL);
    dh->g = BN_new();
    BN_set_word(dh->g, DH_G);
    
    while(!ret) {
        ret = DH_generate_key(dh);
    }
    ret = DH_check_pub_key(dh, dh->pub_key, &i);
    if(ret != 1) {
        NSLog(@"BlufiSecurity Generate DH public key failed");
        return nil;
    }
    
    const int keySize = DH_size(dh);
    unsigned char *keyBuf = malloc(keySize);
    BN_bn2bin(dh->pub_key, keyBuf);
    NSData *publicKey = [NSData dataWithBytes:keyBuf length:keySize];
    BN_bn2bin(dh->priv_key, keyBuf);
    NSData *privateKey = [NSData dataWithBytes:keyBuf length:keySize];
    free(keyBuf);
    
    NSData *p = [NSData dataWithBytes:DH_P length:sizeof(DH_P)];
    Byte gBuf[] = {DH_G};
    NSData *g = [NSData dataWithBytes:gBuf length:1];
    
    BlufiDH *blufiDH = [[BlufiDH alloc] initWithP:p G:g PublicKey:publicKey PrivateKey:privateKey DH:dh];
    return blufiDH;
}
@end
