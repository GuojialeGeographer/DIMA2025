import hilog from '@ohos.hilog';

const TAG = 'AboutPage';
const DOMAIN = 0xFF00;

@Component
export struct AboutPage {
  @State appVersion: string = '1.0.0';
  @State buildNumber: string = '1';
  @State showPrivacyPolicy: boolean = false;
  @State showLicenses: boolean = false;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'AboutPage aboutToAppear');
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('About CityZen')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ left: 20 })

        Blank()
      }
      .width('100%')
      .height(60)
      .backgroundColor('#FFFFFF')
      .alignItems(VerticalAlign.Center)
      .border({
        width: { bottom: 1 },
        color: '#E0E0E0'
      })

      Scroll() {
        Column() {
          this.AppInfoSection()
          this.DescriptionSection()
          this.FeaturesSection()
          this.LegalSection()
          this.ContactSection()
        }
        .width('100%')
        .padding({ top: 10, bottom: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder AppInfoSection() {
    Column() {
      // App Icon and Name
      Column() {
        Image($r('app.media.app_icon'))
          .width(80)
          .height(80)
          .borderRadius(16)
          .margin({ bottom: 16 })

        Text('CityZen')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        Text('Urban Well-being Assistant')
          .fontSize(16)
          .fontColor('#666666')
          .margin({ bottom: 16 })

        Text(`Version ${this.appVersion} (${this.buildNumber})`)
          .fontSize(14)
          .fontColor('#999999')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
  }

  @Builder DescriptionSection() {
    this.SectionCard('About', () => {
      Column() {
        Text('CityZen is an innovative health and well-being application that focuses on environmental quality assessment for urban exercise. Unlike traditional fitness apps that only track quantity metrics, CityZen emphasizes quality metrics by integrating urban environmental data with AI intelligence.')
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(24)
          .margin({ bottom: 16 })

        Text('Built on the OpenHarmony/Oniro ecosystem using ArkTS, CityZen combines real-time environmental data with AI-driven recommendations to help users find the healthiest corners of the city for physical activities.')
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(24)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    })
  }

  @Builder FeaturesSection() {
    this.SectionCard('Key Features', () => {
      Column() {
        this.FeatureItem('🌍', 'Real-time Environmental Assessment', 'Monitor air quality, weather conditions, and environmental factors')
        this.FeatureItem('🤖', 'AI-Powered Recommendations', 'Get personalized exercise suggestions based on current conditions')
        this.FeatureItem('🗺️', 'Smart Interactive Maps', 'Visualize environmental zones and find the best exercise routes')
        this.FeatureItem('📊', 'Exercise History Tracking', 'Record and review your activities with environmental context')
        this.FeatureItem('📱', 'Offline Functionality', 'Continue using core features even without internet connection')
        this.FeatureItem('🔒', 'Privacy Focused', 'Your data stays secure with comprehensive privacy controls')
      }
      .width('100%')
    })
  }

  @Builder LegalSection() {
    this.SectionCard('Legal', () => {
      Column() {
        this.ActionItem('Privacy Policy', () => {
          this.showPrivacyPolicy = true;
        })

        this.ActionItem('Terms of Service', () => {
          // TODO: Show terms of service
        })

        this.ActionItem('Open Source Licenses', () => {
          this.showLicenses = true;
        })

        this.ActionItem('Data Usage Policy', () => {
          // TODO: Show data usage policy
        })
      }
      .width('100%')
    })
  }

  @Builder ContactSection() {
    this.SectionCard('Contact & Support', () => {
      Column() {
        this.InfoItem('Developer', 'CityZen Development Team')
        this.InfoItem('Support Email', 'support@cityzen.app')
        this.InfoItem('Website', 'https://cityzen.app')
        this.InfoItem('GitHub', 'https://github.com/cityzen/cityzen-app')

        Divider()
          .margin({ top: 16, bottom: 16 })
          .color('#F0F0F0')

        Text('Built with ❤️ for urban health and well-being')
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
    })
  }

  @Builder SectionCard(title: string, content: () => void) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ left: 20, top: 16, bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Column() {
        content()
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ left: 16, right: 16, bottom: 16 })
      .padding(20)
    }
    .width('100%')
  }

  @Builder FeatureItem(icon: string, title: string, description: string) {
    Row() {
      Text(icon)
        .fontSize(24)
        .margin({ right: 16 })

      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })

        Text(description)
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 16 })
  }

  @Builder ActionItem(label: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#007AFF')

      Blank()

      Image($r('sys.symbol.chevron_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .height(48)
    .alignItems(VerticalAlign.Center)
    .border({
      width: { bottom: 1 },
      color: '#F0F0F0'
    })
    .onClick(() => {
      onTap();
    })
  }

  @Builder InfoItem(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#333333')
        .fontWeight(FontWeight.Medium)

      Blank()

      Text(value)
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .height(40)
    .alignItems(VerticalAlign.Center)
  }

  @Builder PrivacyPolicyDialog() {
    if (this.showPrivacyPolicy) {
      Column() {
        Text('Privacy Policy')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })

        Scroll() {
          Text(this.getPrivacyPolicyText())
            .fontSize(14)
            .fontColor('#333333')
            .lineHeight(20)
        }
        .layoutWeight(1)
        .margin({ bottom: 20 })

        Button('Close')
          .onClick(() => {
            this.showPrivacyPolicy = false;
          })
      }
      .width('90%')
      .height('80%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .padding(20)
    }
  }

  private getPrivacyPolicyText(): string {
    return `
CityZen Privacy Policy

Last updated: ${new Date().toLocaleDateString()}

1. Information We Collect
CityZen collects location data, environmental preferences, and exercise history to provide personalized recommendations. All data is processed locally on your device when possible.

2. How We Use Your Information
- Provide environmental quality assessments
- Generate personalized exercise recommendations
- Improve app functionality and user experience
- Ensure app security and prevent misuse

3. Data Sharing
We do not sell, trade, or rent your personal information to third parties. Environmental data may be shared with weather and air quality services to provide accurate information.

4. Data Security
We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.

5. Your Rights
You have the right to:
- Access your personal data
- Correct inaccurate data
- Delete your data
- Export your data
- Opt-out of data collection

6. Contact Us
If you have questions about this Privacy Policy, please contact us at privacy@cityzen.app.

This policy may be updated periodically. We will notify you of any significant changes.
    `;
  }
}