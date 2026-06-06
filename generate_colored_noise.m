function noise = generate_colored_noise(N, alpha)
% GENERATE_COLORED_NOISE Renkli gürültü üretimi (v3.1)
%
%   noise = generate_colored_noise(N, alpha)
%
%   Girdiler:
%       N     - Örnek sayısı
%       alpha - Spektral eğim parametresi
%               0: White, 1: Pink, 2: Brown, -1: Blue
%
%   Çıktı:
%       noise - BİRİM GÜÇLÜ kompleks renkli gürültü (E{|x|²} = 1)
%
%   Yöntem: Frekans domeni şekillendirme
%
%   Referans: N.J. Kasdin, "Discrete simulation of colored noise," 
%             Proc. IEEE, vol. 83, no. 5, pp. 802-827, 1995.

    % Kompleks beyaz gürültü (birim varyans)
    white = (randn(N, 1) + 1j * randn(N, 1)) / sqrt(2);
    
    % White noise için direkt dön
    if alpha == 0
        power = mean(abs(white).^2);
        noise = white / sqrt(power);
        return;
    end
    
    % Frekans ekseni [0, 1) normalize frekans
    f = (0:N-1)' / N;
    f(f > 0.5) = f(f > 0.5) - 1;  % Negatif frekanslar
    
    % DC koruması - N'ye bağlı dinamik f_min
    f_min = 2 / N;
    
    f_abs = abs(f);
    f_abs(f_abs < f_min) = f_min;
    
    % Şekillendirme filtresi: |H(f)| = 1/|f|^(alpha/2)
    % PSD: S(f) = |H(f)|² = 1/|f|^alpha
    H = 1.0 ./ (f_abs .^ (alpha/2));
    
    % DC bileşeni sıfırla (ortalama sıfır garantisi)
    H(1) = 0;
    
    % Frekans domeninde uygula
    X = fft(white);
    Y = X .* H;
    noise = ifft(Y);
    
    % BİRİM GÜÇ normalizasyonu: E{|x|²} = 1
    power = mean(abs(noise).^2);
    noise = noise / sqrt(power);
end