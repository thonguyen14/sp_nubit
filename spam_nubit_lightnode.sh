#!/bin/bash


# Pre-defined variables
NETWORK="nubit-alphatestnet-1"
NODE_TYPE="light"
VALIDATOR_IP="validator.nubit-alphatestnet-1.com"
AUTH_TYPE="admin"

BINARY="$HOME/nubit-node/bin/nubit"
BINARYNKEY="$HOME/nubit-node/bin/nkey"
chmod a+x $BINARY
chmod a+x $BINARYNKEY

# Download snapshot
mkdir -p $HOME/nubit_light/
URL=https://nubit.sh/nubit-data/lightnode_data.tgz
cd $HOME/nubit_light/ && chmod -R 777 $HOME/nubit_light/
curl -sLO $URL

cat /root/nubit-node/node_list.txt | while read index name wallet_seedphrase; do
	NODE_PATH=$HOME/nubit_light/nubit_${NODE_TYPE}_${index}

	# Create home dir of node
	mkdir $NODE_PATH
	mkdir $NODE_PATH/.nubit-${NODE_TYPE}-${NETWORK}
	dataPath=$NODE_PATH/.nubit-${NODE_TYPE}-${NETWORK}

	# Extract snapshot data
	tar -xvf $HOME/nubit_light/lightnode_data.tgz -C $dataPath > /dev/null

	# Import keys
	mkdir $dataPath/keys
	echo "$wallet_seedphrase" | $BINARYNKEY add $name --recover --node.type $NODE_TYPE --keyring-dir $dataPath/keys

	# Set ports of node
	PORT_INDEX=$index
	
	CORE_RPC_PORT=$(($PORT_INDEX + 26657))
	CORE_GRPC_PORT=$(($PORT_INDEX + 9090))
	GATEWAY_PORT=$(($PORT_INDEX + 26659))
	RPC_PORT=$(($PORT_INDEX + 26658))
	
	# Initialize new node
	$BINARY $NODE_TYPE init --p2p.network $NETWORK --node.store $dataPath --gateway.port $GATEWAY_PORT --rpc.port $RPC_PORT

	# Extract pubkey
	pubkey=$($BINARYNKEY list --p2p.network $NETWORK --node.type $NODE_TYPE --keyring-dir $dataPath/keys --output json  | jq -r .[].pubkey | jq -r .key)
	address=$($BINARYNKEY list --p2p.network $NETWORK --node.type $NODE_TYPE --keyring-dir $dataPath/keys --output json  | jq -r .[].address)
	name=$($BINARYNKEY list --p2p.network $NETWORK --node.type $NODE_TYPE --keyring-dir $dataPath/keys --output json  | jq -r .[].name)
	echo -e "$name\t$address\t$pubkey" >> $HOME/nubit_light/nubit_key.txt

	# Star node
	export AUTH_TYPE
	$BINARY $NODE_TYPE auth $AUTH_TYPE --node.store $dataPath

	sudo tee /etc/systemd/system/nubit_${NODE_TYPE}_${index}.service > /dev/null <<EOF
[Unit]
Description=nubit_${NODE_TYPE}_${index}
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$BINARY $NODE_TYPE start --p2p.network $NETWORK --core.ip $VALIDATOR_IP --metrics.endpoint otel.nubit-alphatestnet-1.com:4318 --rpc.skip-auth --node.store $dataPath --node.config $dataPath/config.toml --keyring.accname $name
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload && sudo systemctl enable nubit_${NODE_TYPE}_${index}
	sudo systemctl restart nubit_${NODE_TYPE}_${index}

done
