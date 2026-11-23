import type { Amenity, PropertyType, TransactionType } from './constants';

export type UserRole = 'user' | 'owner' | 'agent' | 'admin';

export interface UserProfile {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  photoUrl?: string | null;
  role: UserRole;
  status: string;
}

export interface Property {
  id: string;
  ownerId: string;
  agentId?: string | null;
  ownerName?: string | null;
  ownerRole?: string | null;
  title: string;
  description: string;
  transactionType: TransactionType;
  propertyType: PropertyType;
  price: number;
  currency: string;
  surface?: number | null;
  bedrooms?: number | null;
  bathrooms?: number | null;
  governorate: string;
  city?: string | null;
  area?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  images: string[];
  amenities: Amenity[];
  status: string;
  views: number;
  favoritesCount: number;
  publishedAt?: Date | null;
  createdAt?: Date | null;
  expiresAt?: Date | null;
}

export interface Conversation {
  id: string;
  participants: string[];
  userId: string;
  recipientId: string;
  propertyId: string;
  userName?: string | null;
  recipientName?: string | null;
  propertyTitle?: string | null;
  propertyImage?: string | null;
  lastMessage?: string | null;
  lastMessageAt?: Date | null;
  lastSenderId?: string | null;
  lastReadAt: Record<string, Date>;
}

export interface ChatMessage {
  id: string;
  senderId: string;
  text: string;
  createdAt?: Date | null;
  pending: boolean;
}

export interface AppNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  read: boolean;
  conversationId?: string | null;
  propertyId?: string | null;
  createdAt?: Date | null;
}
