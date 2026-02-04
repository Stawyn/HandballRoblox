--[[
    ================================================================================
    MÓDULO: ABHAnimations
    ================================================================================
    Descrição: Dicionário centralizado de referências de animações do jogo ABH.
               Carrega todas as animações da pasta Animations no ReplicatedStorage.
    
    Animações Disponíveis:
        - HoldBall: Segurar a bola
        - KeeperAnimation: Posição de goleiro
        - LHandChargeThrow/RHandChargeThrow: Carregar arremesso
        - LHandThrow/RHandThrow: Arremessar
        - LHandTackle/RHandTackle: Tackle/Roubo
        - SwitchHands: Trocar de mão
    
    Autor: Sistema ABH
    ================================================================================
]]

--// ============================================================================
--// SETOR: SERVIÇOS E REFERÊNCIAS
--// ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ANIMATIONS_FOLDER = ReplicatedStorage:WaitForChild("Animations") :: Folder 

--// ============================================================================
--// SETOR: DICIONÁRIO DE ANIMAÇÕES
--// ============================================================================

return {
	-- Posse da bola
	HoldBall = ANIMATIONS_FOLDER:WaitForChild("HoldBall") :: Animation,
	
	-- Goleiro
	KeeperAnimation = ANIMATIONS_FOLDER:WaitForChild("KeeperAnimation") :: Animation,
	
	-- Carregar arremesso
	LHandChargeThrow = ANIMATIONS_FOLDER:WaitForChild("LHandChargeThrow") :: Animation,
	RHandChargeThrow = ANIMATIONS_FOLDER:WaitForChild("RHandChargeThrow") :: Animation,
	
	-- Arremesso
	LHandThrow = ANIMATIONS_FOLDER:WaitForChild("LHandThrow") :: Animation,
	RHandThrow = ANIMATIONS_FOLDER:WaitForChild("RHandThrow") :: Animation,
	
	-- Tackle/Roubo
	LHandTackle = ANIMATIONS_FOLDER:WaitForChild("LHandTackle") :: Animation,
	RHandTackle = ANIMATIONS_FOLDER:WaitForChild("RHandTackle") :: Animation,
	
	-- Utilitários
	SwitchHands = ANIMATIONS_FOLDER:WaitForChild("SwitchHands") :: Animation,
}