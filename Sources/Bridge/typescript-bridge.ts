/**
 * METAL Bridge - TypeScript Interface
 * This provides the TypeScript side of the Swift/TypeScript communication bridge
 */

interface MetalBridgeMessage {
    id: string;
    type: 'request' | 'response' | 'error';
    payload: any;
    timestamp: number;
}

class MetalBridgeTS {
    private messageQueue: Map<string, { resolve: (value: any) => void; reject: (error: any) => void }> = new Map();
    private messageIdCounter: number = 0;
    
    constructor() {
        this.setupMessageListener();
    }
    
    /**
     * Send a message to the Swift layer via METAL bridge
     */
    async sendToSwift(message: any): Promise<any> {
        const messageId = `msg_${++this.messageIdCounter}_${Date.now()}`;
        
        return new Promise((resolve, reject) => {
            this.messageQueue.set(messageId, { resolve, reject });
            
            const metalMessage: MetalBridgeMessage = {
                id: messageId,
                type: 'request',
                payload: message,
                timestamp: Date.now()
            };
            
            // Send to Swift via window.webkit.messageHandlers
            if (window.webkit?.messageHandlers?.metalBridge) {
                window.webkit.messageHandlers.metalBridge.postMessage(metalMessage);
            } else {
                // Fallback: try direct postMessage
                window.postMessage(metalMessage, '*');
            }
            
            // Timeout after 30 seconds
            setTimeout(() => {
                if (this.messageQueue.has(messageId)) {
                    this.messageQueue.delete(messageId);
                    reject(new Error('Request timeout'));
                }
            }, 30000);
        });
    }
    
    /**
     * Send message to local Mistral AI
     */
    async sendToAI(message: string): Promise<string> {
        try {
            const response = await this.sendToSwift({
                action: 'sendToAI',
                message: message
            });
            return response.content || response;
        } catch (error) {
            console.error('Error sending to AI:', error);
            throw error;
        }
    }
    
    /**
     * Handle responses from Swift layer
     */
    private handleResponseFromSwift(message: MetalBridgeMessage) {
        const handler = this.messageQueue.get(message.id);
        if (handler) {
            this.messageQueue.delete(message.id);
            if (message.type === 'error') {
                handler.reject(new Error(message.payload));
            } else {
                handler.resolve(message.payload);
            }
        }
    }
    
    /**
     * Setup message listener for responses from Swift
     */
    private setupMessageListener() {
        // Listen for messages from Swift
        window.addEventListener('message', (event: MessageEvent) => {
            if (event.data && event.data.id && event.data.type) {
                this.handleResponseFromSwift(event.data as MetalBridgeMessage);
            }
        });
        
        // Expose global handler for Swift to call directly
        (window as any).metalBridgeResponse = (message: MetalBridgeMessage) => {
            this.handleResponseFromSwift(message);
        };
    }
}

// Initialize and expose globally
const metalBridge = new MetalBridgeTS();
(window as any).metalBridge = metalBridge;

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = metalBridge;
}

// TypeScript declarations
declare global {
    interface Window {
        metalBridge?: MetalBridgeTS;
        metalBridgeResponse?: (message: MetalBridgeMessage) => void;
        webkit?: {
            messageHandlers?: {
                metalBridge?: {
                    postMessage: (message: any) => void;
                };
            };
        };
    }
}

export default metalBridge;

