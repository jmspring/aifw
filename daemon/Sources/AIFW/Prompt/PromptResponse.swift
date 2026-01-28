//
// PromptResponse.swift
// AIFW
//
// User prompt response types
//

import Foundation

/// User's response to a prompt
public enum PromptResponse: Equatable {
    case deny
    case allowOnce
    case allowAlways
}
