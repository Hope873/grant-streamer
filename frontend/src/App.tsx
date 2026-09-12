import './App.css'
import { useState } from 'react'
import { useAccount, useConnect, useDisconnect } from 'wagmi'

function App() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const [showWallets, setShowWallets] = useState(false)

  const handleWallet = () => {
    if (isConnected) {
      disconnect()
      return
    }

    setShowWallets((current) => !current)
  }

  const handleConnect = (connector: (typeof connectors)[number]) => {
    connect(
      { connector },
      {
        onSuccess: () => setShowWallets(false),
      },
    )
  }

  const walletLabel = isConnected
    ? `${address?.slice(0, 6)}...${address?.slice(-4)}`
    : isPending
      ? 'Connecting...'
      : 'Connect wallet'

  return (
    <main className="app">
      <header className="header">
        <div>
          <p className="eyebrow">DAO GRANTS</p>
          <h1>Grant Streamer</h1>
          <p className="subtitle">
            Create and manage transparent token streams for your grants.
          </p>
        </div>

        <div className="wallet-picker">
          <button
            className="connect-button"
            type="button"
            onClick={handleWallet}
            disabled={isPending}
          >
            {walletLabel}
          </button>

          {showWallets && !isConnected && (
            <div className="wallet-menu">
              {connectors.map((connector) => (
                <button
                  className="wallet-option"
                  key={connector.uid}
                  type="button"
                  onClick={() => handleConnect(connector)}
                >
                  {connector.name}
                </button>
              ))}
            </div>
          )}
        </div>
      </header>

      <section className="hero-card">
        <div>
          <p className="eyebrow">ARBITRUM SEPOLIA</p>
          <h2>Stream grants, not spreadsheets.</h2>
          <p>
            Fund a grant once and let recipients receive their allocation
            continuously over time.
          </p>
          <button className="primary-button" type="button">
            Create a grant stream
          </button>
        </div>

        <div className="status-card">
          <span className="status-dot" />
          <div>
            <strong>Controller online</strong>
            <span>GrantStreamController</span>
          </div>
        </div>
      </section>

      <section className="stats">
        <article>
          <span>Network</span>
          <strong>Arbitrum Sepolia</strong>
        </article>

        <article>
          <span>Controller</span>
          <strong>0x5E61...F4bB</strong>
        </article>

        <article>
          <span>Wallet</span>
          <strong>{isConnected ? walletLabel : 'Not connected'}</strong>
        </article>
      </section>

      <section className="streams">
        <div className="section-heading">
          <div>
            <p className="eyebrow">STREAMS</p>
            <h2>Your grant streams</h2>
          </div>
          <span className="muted">
            {isConnected
              ? 'Wallet connected'
              : 'Connect a wallet to continue'}
          </span>
        </div>

        <div className="empty-state">
          <div className="empty-icon">→</div>
          <h3>No streams to display</h3>
          <p>
            {isConnected
              ? 'Your grant streams will appear here once we connect the controller data.'
              : 'Connect your wallet to view grant streams and manage your grants.'}
          </p>
        </div>
      </section>
    </main>
  )
}

export default App
