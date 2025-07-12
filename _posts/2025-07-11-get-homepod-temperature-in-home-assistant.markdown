---
layout: post
title:  "Get Homepod temperature in Home-Assistant"
date:   2025-07-11 22:05:14 +0800
categories: Home-Assistant
---
It is getting hot in here. And my AC does not support any smart home things. To save the energy for it to run for nothing, I planned to have a notification when room temperature is above 30℃.

I have only one temperature sensor, that is Homepod2. Hence I have two options. One, get notification from HomeKit. Two, get notification from Home-Assistant.

For option one, since HomeKit actually runs in the hub, which is Homepod, therefore its automation functions are limited, so is its Shortcut. And funny enough, HomeKit does not consider iPhone as a device, it cannot do anything with it. So to sum up, I cannot directly get a notification on iPhone, when temperature goes above 30℃.

But I noticed that Homepod Shortcut can do some web actions. This is where [Pushdeer](https://github.com/easychen/pushdeer) comes to rescue. Install the app on iPhone, register, get a key. Setup HomeKit automation, at event of temperature goes above 30℃, run Shortcut of `GET` content of `https://${PUSHDEER_API}?pushkey=${THE_KEY}&text=It%20iss%20too%20hot`.

This is enough for the requirement, but it may be better if there is a statics history, and not depending on external service of good will. Further more, if it could be easily extended.

Therefore I also setup option two, in case when I needed the hard way.

First of all, Homepod does not support exposing its sensors to Home-Assistant. So this solution actually is exposing a persudo switch from Home-Assistant to HomeKit. And in Home-Assistant automation, it frequently turns on and off the switch. Then HomeKit senses the change (since it knows the switch), runs a corresponding automation, which `POST` the values of sensors to another persudo sensor in Home-Assistant via webhook.

After this setup, we can do whatever we can do in Home-Assistant about a sensor, triggering actions, record history data, etc.

Now let's see the detail steps.

1. Install the "File editor" add-on.

    Steps here but one can be done via WebUI. The one cannot be done at all. And since Home-Assistant may store those configurations from WebUI in different formation in different places, to make things easier and clearer, all will be IaC.

2. Edit configuration.yaml.

    Although system infor says that configuration.yaml is under /config, and File editor locks its workdir in /homeassistant, actually it is the same file.

3. Create persudo switch. Add following code as a new section (no pre-indent).

    ```yaml
    input_boolean:
      collection_of_homekit_sensors:
        name: "Collector of HomeKit Sensors"
    ```

4. Reload.

    In WebUI, click the username at bottom-left to open profile page. Scroll down, seeking "Advanced mode" and turn it on.

    Item "Developer tools" appears in navigator. Click it, there is a red "RESTART" link. Click it. If there is not a green string "Configuration will not prevent Home Assistant from starting!" showing, check the change in configuration.yaml. If it appears, click "Quick reload" in the popup.

5. Install the [HomeKit Bridge](https://www.home-assistant.io/integrations/homekit/) integration.

    After the installation, there would be a QR code showing at the top-left of WebUI. Use HomeKit Add Device to scan it, following its prompt, adding other devices from Home-Assistant to HomeKit, AND the switch above.

6. Create automation.

    Every 5 mins, turn on the switch, wait 5 secs, turn off the switch.

    ```yaml
    automation homepod:
    - alias: HomePod - Sensor Collection
      triggers:
      - trigger: time_pattern
        minutes: /5
      actions:
      - action: input_boolean.turn_on
        target:
          entity_id: input_boolean.collection_of_homekit_sensors
      - delay:
          hours: 0
          minutes: 0
          seconds: 5
          milliseconds: 0
      - action: input_boolean.turn_off
        target:
          entity_id: input_boolean.collection_of_homekit_sensors
      mode: single
    ```

7. Create sensor.

    ```yaml
    template:
      - triggers:
          - trigger: webhook
            webhook_id: homepod-sensors
            allowed_methods:
              - POST
            local_only: false
        sensor:
          - name: "HomePod Temperature"
            state: "{{ trigger.json.temperature }}"
            state_class: "measurement"
            device_class: TEMPERATURE
    ```

8. Reload.

9. Create HomeKit automation.

    When "Collector of HomeKit Sensors" is on, run Shortcut.

    In the Shortcut, first step is getting current value of temperature sensor.

    Second step is getting number from current value. The "current value" ends with "℃", which would be treated as string in Home-Assistant, hence statics would not work and errors would be reported. And another fun thing is that, although it returns in "℃", every time I ask Homepod what is the room temperature, it says it in "℉".

    Third step is `POST` to `http://${HOME_ASSISTANT_ADDRESS}/api/webhook/homepod-sensors`, with `JSON` body, which contains field key `temperature` and the number of former step as value.

Now everything is done. Give it 5 mins to update. Then in default Dashboard, the temperature would appear as the sensor value. And further more, click the value, a chart would appear.
