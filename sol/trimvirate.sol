contract triumvirate {
  uint constant THREE = 3;

  address one;
  address two;
  address three;

  bool accept_one = false;
  bool accept_two = false;
  bool accept_three = false;

  uint256 total_wei = 0;


  function triumvirate(address two, address three) {
    one = msg.sender;
    two = _two;
    three = _three;
  }

  function() {
    total_wei += msg.value;
  }

  function accept() {
    if (msg.sender == one) {
      accept_one = true;
    } else if (msg.sender == two) {
      accept_two = true;
    } else {
      accept_three = true;
    }
  }

  function kill() {
    if (!accept_one || !accept_two || !accept_three) { throw; }

    uint256 third = total_wei / THREE;
    three.send(third);
    two.send(third);
    suicide(one);
  }
}
