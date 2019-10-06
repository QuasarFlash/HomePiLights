import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:responsive_grid/responsive_grid.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(new MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Pi Lights',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter + IoT + PiZeroW'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static String broker = '192.168.1.159';
  static int port = 1883;
  // String username         = 'fcg.._seu_user_no_brokerrix';
  // String passwd           = '0qVi...seu_pass_no_nroker';
  static String clientIdentifier = 'android';
  static String topic = "lightbulb/state";
  mqtt.MqttClient client =
      mqtt.MqttClient.withPort(broker, clientIdentifier, port);

  mqtt.MqttConnectionState connectionState;
  bool connectState = false;
  final List<bool> isSelected = [false, false, false, false, false, false];

  Widget lightIcon(label, index, {xs = 12, md = 3, size = 30.0}) {
    return ResponsiveGridCol(
      xs: xs,
      md: md,
      child: Container(
        height: 100,
        alignment: Alignment(0, 0),
        color: Colors.grey[200],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
                icon: Icon(
                  Icons.lightbulb_outline,
                ),
                iconSize: size * 1.8,
                onPressed: () {
                  setState(() {
                    isSelected[index] = !isSelected[index];
                    if (isSelected[index] == true) {
                      _publish(topic, "$index on");
                    } else {
                      _publish(topic, "$index off");
                    }
                    if (index == 0) {
                      isSelected.fillRange(1, 5, isSelected[index]);
                    }
                  });
                },
                color: (isSelected[index]) ? Colors.yellow : Colors.black),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget showPower() {
    return ResponsiveGridCol(
      lg: 12,
      child: Container(
        alignment: FractionalOffset.center,
        child: IconButton(
          icon: Icon(Icons.power_settings_new),
          iconSize: 150,
          color: connectState ? Colors.green : Colors.red,
          onPressed: connectState ? _brokerDisconnect : _connect,
        ),
      ),
    );
  }

  Widget showLightsWidget() {
    return ResponsiveGridRow(
      children: [
        showPower(),
        lightIcon("All", 0),
        lightIcon("Light 1", 1, xs: 6, md: 3),
        lightIcon("Light 2", 2, xs: 6, md: 3),
        lightIcon("Light 3", 3, xs: 6, md: 3),
        lightIcon("Light 4", 4, xs: 6, md: 3),
        lightIcon("Light 5", 5, xs: 6, md: 3),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: showLightsWidget(),

      // floatingActionButton: FloatingActionButton(
      //   onPressed: _connect,
      //   tooltip: 'Play',
      //   child: Icon(Icons.play_arrow),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _connect() async {
    /// First create a client, the client is constructed with a broker name, client identifier
    /// and port if needed. The client identifier (short ClientId) is an identifier of each MQTT
    /// client connecting to a MQTT broker. As the word identifier already suggests, it should be unique per broker.
    /// The broker uses it for identifying the client and the current state of the client. If you don’t need a state
    /// to be hold by the broker, in MQTT 3.1.1 you can set an empty ClientId, which results in a connection without any state.
    /// A condition is that clean session connect flag is true, otherwise the connection will be rejected.
    /// The client identifier can be a maximum length of 23 characters. If a port is not specified the standard port
    /// of 1883 is used.
    /// If you want to use websockets rather than TCP see below.
    ///
    // client = mqtt.MqttClient(broker, '');
    // client.port = port;

    /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
    /// for details.
    /// To use websockets add the following lines -:
    /// client.useWebSocket = true;
    /// client.port = 80;  ( or whatever your WS port is)
    /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.

    /// Set logging on if needed, defaults to off
    client.logging(on: false);

    /// If you intend to use a keep alive value in your connect message that is not the default(60s)
    /// you must set it here
    client.keepAlivePeriod = 20;

    /// Add the unsolicited disconnection callback
    client.onDisconnected = onDisconnected;

    /// Add the successful connection callback
    client.onConnected = onConnected;

    /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
    /// You can add these before connection or change them dynamically after connection if
    /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
    /// can fail either because you have tried to subscribe to an invalid topic or the broker
    /// rejects the subscribe request.
    client.onSubscribed = onSubscribed;

    /// Set a ping received callback if needed, called whenever a ping response(pong) is received
    /// from the broker.
    client.pongCallback = pong;

    /// Create a connection message to use or use the default one. The default one sets the
    /// client identifier, any supplied username/password, the default keepalive interval(60s)
    /// and clean session, an example of a specific one below.
    final mqtt.MqttConnectMessage connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .keepAliveFor(20) // Must agree with the keep alive set above or not set
        .withWillTopic(
            'willtopic') // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(mqtt.MqttQos.atLeastOnce);
    print('EXAMPLE::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however eill
    /// never send malformed messages.
    try {
      await client.connect();
    } on Exception catch (e) {
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    }

    /// Check we are connected
    if (client.connectionStatus.state == mqtt.MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');
    } else {
      /// Use status here rather than state if you also want the broker return code.
      print(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      client.disconnect();
    }


  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
    setState(() {
      connectState = true;
    });
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus.returnCode ==
        mqtt.MqttConnectReturnCode.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    }
    setState(() {
      connectState = false;
    });
  }

  /// The successful connect callback
  void onConnected() {
    print(
        'EXAMPLE::OnConnected client callback - Client connection was sucessful');
    setState(() {
      connectState = true;
    });
  }

  /// Pong callback
  void pong() {
    print('EXAMPLE::Ping response client callback invoked');
  }

  void _publish(topic, msg) async {
    /// Lets publish to our topic
    /// Use the payload builder rather than a raw buffer
    /// Our known topic to publish to
    String pubTopic = topic;
    final mqtt.MqttClientPayloadBuilder builder =
        mqtt.MqttClientPayloadBuilder();
    builder.addString(msg);

    /// Subscribe to it
    print('EXAMPLE::Subscribing to the lightbulb/state topic');
    client.subscribe(pubTopic, mqtt.MqttQos.exactlyOnce);

    /// Publish it
    print('EXAMPLE::Publishing our topic');
    client.publishMessage(pubTopic, mqtt.MqttQos.exactlyOnce, builder.payload);

    /// Ok, we will now sleep a while, in this gap you will see ping request/response
    /// messages being exchanged by the keep alive mechanism.
    print('EXAMPLE::Sleeping....');
    await mqtt.MqttUtilities.asyncSleep(120);

    /// Finally, unsubscribe and exit gracefully
    print('EXAMPLE::Unsubscribing');
    client.unsubscribe(topic);

    /// Wait for the unsubscribe message from the broker if you wish.
    await mqtt.MqttUtilities.asyncSleep(2);
    print('EXAMPLE::Disconnecting');
    onDisconnected();
  }

  void _brokerDisconnect() {
    client.disconnect();
  }
}
