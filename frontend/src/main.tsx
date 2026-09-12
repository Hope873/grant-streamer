import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiProvider, createConfig, http } from 'wagmi'
import { arbitrumSepolia } from 'wagmi/chains'
import {
  coinbaseWallet,
  injected,
  walletConnect,
} from 'wagmi/connectors'
import './index.css'
import App from './App.tsx'

const walletConnectProjectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID

const config = createConfig({
  chains: [arbitrumSepolia],
  connectors: [
    injected(),
    coinbaseWallet({
      appName: 'Grant Streamer',
    }),
    walletConnect({
      projectId: walletConnectProjectId,
      showQrModal: true,
    }),
  ],
  transports: {
    [arbitrumSepolia.id]: http(),
  },
})

const queryClient = new QueryClient()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </StrictMode>,
)
