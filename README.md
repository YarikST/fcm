# Firebase Cloud Messaging (FCM) for Android and iOS
[![Gem Version](https://badge.fury.io/rb/fcm.svg)](http://badge.fury.io/rb/fcm) [![Build Status](https://secure.travis-ci.org/spacialdb/fcm.png?branch=master)](http://travis-ci.org/spacialdb/fcm)

The FCM gem lets your ruby backend send notifications to Android and iOS devices via [
Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/).

## Installation

    $ gem install fcm

or in your `Gemfile` just include it:

```ruby
gem 'fcm'
```

## Requirements

For Android you will need a device running 2.3 (or newer) that also have the Google Play Store app installed, or an emulator running Android 2.3 with Google APIs. iOS devices are also supported.

One of the following, tested Ruby versions:

* `2.0.0`
* `2.1.9`
* `2.2.5`
* `2.3.1`

## Usage

### Add/Remove Registration Tokens in Topic

You can also add/remove registration Tokens to/from a particular `topic`. For example:

```ruby
response = fcm.add_to_topic(topic: "movies", registration_ids:["7", "3"])

response = fcm.remove_to_topic(topic: "movies", registration_ids:["7", "3"])
```

## Send Messages to Topics

FCM [topic messaging](https://firebase.google.com/docs/cloud-messaging/topic-messaging) allows your app server to send a message to multiple devices that have opted in to a particular topic. Based on the publish/subscribe model, topic messaging supports unlimited subscriptions per app. Sending to a topic is very similar to sending to an individual device or to a user group, in the sense that you can use the `fcm.send_with_notification_key()` method where the `notification_key` matches the regular expression `"/topics/[a-zA-Z0-9-_.~%]+"`:


```ruby
response = fcm.send_to_topic("yourTopic",
            data: {message: "This is a FCM Topic Message!")
```

### Sending to Multiple Topics

To send to combinations of multiple topics, the FCM [docs](https://firebase.google.com/docs/cloud-messaging/send-message#send_messages_to_topics_2) require that you set a **condition** key (instead of the `to:` key) to a boolean condition that specifies the target topics. For example, to send messages to devices that subscribed to _TopicA_ and either _TopicB_ or _TopicC_:

```
'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)
```

FCM first evaluates any conditions in parentheses, and then evaluates the expression from left to right. In the above expression, a user subscribed to any single topic does not receive the message. Likewise, a user who does not subscribe to TopicA does not receive the message. These combinations do receive it:

- TopicA and TopicB
- TopicA and TopicC

You can include up to five topics in your conditional expression, and parentheses are supported. Supported operators: `&&`, `||`, `!`. Note the usage for !:

```
!('TopicA' in topics)
```

With this expression, any app instances that are not subscribed to TopicA, including app instances that are not subscribed to any topic, receive the message.

The `send_to_topic_condition` method within this library allows you to specicy a condition of multiple topics to which to send to the data payload.

```ruby
response = fcm.send_to_topic_condition(
  "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)",
  data: {
    message: "This is an FCM Topic Message sent to a condition!"
  }
)
```


## Mobile Clients

You can find a guide to implement an Android Client app to receive notifications here: [Set up a FCM Client App on Android](https://firebase.google.com/docs/cloud-messaging/android/client).

The guide to set up an iOS app to get notifications is here: [Setting up a FCM Client App on iOS](https://firebase.google.com/docs/cloud-messaging/ios/client).

## ChangeLog

### 0.0.2

* Fixed group messaging url.
* Added API to `recover_notification_key`.

### 0.0.1

* Initial version.

##MIT License

* Copyright (c) 2016 Kashif Rasul and Shoaib Burq. See LICENSE.txt for details.

##Many thanks to all the contributors

* [Contributors](https://github.com/spacialdb/fcm/contributors)

## Donations
We accept tips through [Gratipay](https://gratipay.com/spacialdb/).

[![Gratipay](https://img.shields.io/gratipay/spacialdb.svg)](https://www.gittip.com/spacialdb/)
