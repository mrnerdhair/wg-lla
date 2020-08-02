# wg-lla

This is an implementation of an algorithm which assigns WireGuard peers unique IPv6 Link-Local Addresses based on a hash of their public key. The general concept is fairly straightforward, and similar systems have been developed independently several times. Still, differing implementation details have prevented compatibility between systems. The goal of this project is to provide a thorough enumeration of the points of divergence between these sorts of algorithms, a set of sensible defaults, and a reference implementation usable by any system cabable of running the typical `wg` and `wg-quick` userland tools.

### Why?
One of the primary difficulties when bootstrapping a WireGuard VPN is the lack of a default link-local addressing mechanism. WireGuard's cryptokey routing requires that addressing be established before any communication can take place, but there are a variety of interesting scenarios in which it would be useful to be able to address a specific peer by public key instead of using an addressing scheme which must be established out-of-band beforehand. A typical network interface can use link-local addressing to bootstrap a higher-level addressing protocol or to ensure that requests processed by a server come from a peer with a presence on a specific link; a link-local addressing scheme would enable WireGuard be a much more versatile protocol.

### How can I tell if I'm compatible?

The LLA assignment scheme described here assigns the address `fe8b:5ea9:9e65:3bc2:b593:db41:30d1:0a4e` to the all-zero public key (`AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`).

### Isn't doing a hash with a shell script really slow?

Yes. 50ms per hash is typical, which is very slow as hashes go. But it's still fast enough for many purposes, and it provides a universally-compatible lowest common denominator.

The `b2sum` utility is used if avaliable, which is much faster. Be careful, though: there are two different utilities called `b2sum`, and the GNU coreutils version (which is the one your package manager probably provides) only does Blake2b, not Blake2s. You'll need the [other one][1], which is the reference implementation created by the authors of Blake2 itself.

## An Enumeration of the Points of Divergence, and Sensible Defaults For Each

### Should a hash be taken of the key itself, or its Base64 encoding?
#### The key itself.

While the WireGuard tools are fairly consistent in the use of the Base64 encoding in user-facing scenarios, it's important to consider that there's nothing fundamental about the WireGuard protocol itself that requires the use of Base64 anywhere. It would be inappropriate to introduce a dependency on it for address calculation.

### What algorithm should the hash be performed with?
#### Blake2s-256.

Some existing implementations of a WireGuard LLA assignment scheme use a hash algorithm such as SHA-256. However, implementing WireGuard already requires that Blake2s-256 be available, as it is both the `HASH()` function in the WireGuard protocol specification and the hash function chosen for the Noise construction. Blake2s is already the obvious choice for LLA assignment in constrained environments like microcontrollers, but the lack of a common userland utility for calculating these hashes has made its adoption difficult. This project's reference implementation includes a self-contained Blake2s implementation for this reason, though installation of the `b2sum` utility provided by the Blake2 authors will improve performance.

### What netmask should be used?
#### fe80::/10.

RFC 4291 section 2.5.6 specifies LLAs to be addresses of the form `fe80::/64`, but section 2.4 reserves the entire `fe80::/10` block for these addresses. We deviate from the RFC recommendation of `/64` here by using the whole reserved `/10` block, which we are able to do without fear of collision with future extensions to the standard because we are using a collision-resistant cryptographic hash. In a VPN application is it very desirable that each address be strongly bound to the key it is derived from. 64 bits is insufficient for this purpose, but 118 bits is.

A strong cryptographic binding between key and address requires that it be infeasable for an attacker to find a key which matches a given address. Finding a second pre-image that matches a given address is not enough, because it is useless to an attacker to find a second public key that matches an address unless the attacker has the associated secret key. That means an attacker cannot simply guess a public key and run it through a hash function -- they must instead guess a private key, perform an elliptic curve point multiplication to find the associated public key, and then run **that** through the hash. That ECC point multiplication operation is very expensive, and amounts to a form of key stretching just like password hashes like PBKDF2 or Argon2 do.

Wireguard targets a 128-bit security level, and this stretching effect more than makes up for the 10 bits of security lost by applying the `fe80::/10` netmask. For reference, Curve25519 takes [832457 cycles][2] for a single scalar multiplication; Blake2s on a single 64-byte block takes [5.5 cycles per byte][3], or 352 cycles. That makes the combined guess-and-check operation take ~2300x longer, a comfortable margin higher than the 1024x slowdown required to compensate for the lost 10 bits of the netmask. (Admittedly, these numbers are different microarchitectures so it's kind of an apples-to-oranges thing, but we're talking orders of magnitude here.)

### Should the subnet identifier be concatenated with the results of the hash, or should leading bits of the hash be dropped?
#### (SUBNET & MASK) | (HASH & ~MASK)

Binary math is good, cheap, and obvious, whereas concatenation is only straightforward if the netmask is a whole number of bytes. Additionally, masking off the leading bits causes the interface identifier (the trailing 64 bits) associated with an address to be identical between addresses calculated for subnets of different sizes.

[1]: https://blake2.net/#su
[2]: https://cr.yp.to/ecdh/curve25519-20051115.pdf
[3]: https://blake2.net/blake2.pdf
