%% =====================================================================
%  SIU 2026 - RENKLI GÜRÜLTÜ KARIŞTIRMANIN MTI-CFAR RADAR
%             DEDEKTÖR PERFORMANSINA ETKİSİ
%  =====================================================================
%  Versiyon: 3.1 (Final + Pfa kontrol güçlendirmesi)
%
%  v3.0 → v3.1 DEĞİŞİKLİKLER:
%    [D17] N_mc_pfa_kontrol: 100 → 400 (beklenen FA: ~4 → ~17)
%    [D18] Pfa_gercek: min/maks/ortalama raporlanıyor + SNR'ye karşı grafik
%    [D19] MTI notch bölgesi filtre cevabından (|H|²=1 eşiği) türetiliyor
%
%  v2 → v3 DEĞİŞİKLİKLER:
%    [D11] Pd deneylerinde "gerçekleşen Pfa" ayrıca ölçülüyor
%          → Pd düşüşünün kaynağı (jammer mı, eşik uyumsuzluğu mu?) ayrılır
%    [D12] v_tarama 0.5 m/s'den başlıyor (MTI notch bölgesi görünür)
%    [D13] complex(zeros(...)) ile preallocation
%    [D14] T_ust sınır kontrolü ve uyarı
%    [D15] mti_filtre_matris boyut kontrolü
%    [D16] Kalibrasyon sonrası T ile eşleşen Pfa yazdırılıyor
%
%  Önceki düzeltmeler (v1→v2):
%    [D1]  JSR = P_jam / P_sig sabit tutulur
%    [D2]  Pfa_tasarım = 1e-3
%    [D3]  Sonuç cümleleri veriden otomatik
%    [D4]  Otokorelasyon yorumu düzeltildi
%    [D5]  hedef_idx: floor()
%    [D6]  Vektör yönleri (:).'
%    [D7]  cfar_ref_hesapla: (:) kolon zorlama
%    [D8]  rng(42) tekrarlanabilirlik
%    [D9]  mti_beyaz_kazanc_dB isim netleştirildi
%    [D10] Güven sınırı "yaklaşık referans"
%
%  Bağımlılık: generate_colored_noise.m (aynı klasörde olmalı)
%
%  NOT: Fonksiyonlar MATLAB R2016b+ gerektirir (script-local function).
%       Daha eski sürüm için fonksiyonları ayrı .m dosyalarına taşıyın.
%
%  Süleyman Kaan Çetin - Yüksek Lisans Tezi / SIU 2026
%  =====================================================================
clear; clc; close all;
%% [D8] TEKRARLANABİLİRLİK
rng(42);
%% ─────────────── TEZ GRAFİK STİLİ ───────────────
set(groot, 'defaultFigureColor', 'w');
set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 13);
set(groot, 'defaultTextFontSize', 13);
set(groot, 'defaultLineLineWidth', 2.0);
set(groot, 'defaultAxesLineWidth', 1.1);
set(groot, 'defaultAxesGridLineStyle', ':');
set(groot, 'defaultAxesXGrid', 'on');
set(groot, 'defaultAxesYGrid', 'on');
out_dpi = 300;
%% ─────────────── FONKSİYON KONTROLÜ ───────────────
if ~exist('generate_colored_noise', 'file')
    error('generate_colored_noise.m bulunamadı! Aynı klasöre kopyalayın.');
end
%% ═══════════════ PARAMETRELER ═══════════════
fc  = 10e9;
c   = 3e8;
lam = c / fc;
PRF = 5000;
v_max = lam * PRF / 4;
% MTI filtresi: Çift iptal edici
mti_koef = [1, -2, 1];
mti_beyaz_kazanc_dB = 10*log10(sum(mti_koef.^2));  % [D9] 7.78 dB
% Gürültü tipleri
gurultu_adi   = {'Beyaz', 'Pembe', 'Kahverengi', 'Mavi'};
alpha_degeri  = [0, 1, 2, -1];
gurultu_renk  = [0.00 0.50 0.00;
                 0.90 0.40 0.60;
                 0.60 0.30 0.10;
                 0.20 0.40 0.90];
n_gurultu = numel(gurultu_adi);
% CFAR parametreleri
N_ref_tek_taraf = 8;
N_koruma        = 1;
N_ref_toplam    = 2 * N_ref_tek_taraf;
Pfa_tasarim     = 1e-3;  % [D2]
cfar_adi = {'CA-CFAR', 'GO-CFAR', 'SO-CFAR', 'OS-CFAR'};
n_cfar   = numel(cfar_adi);
% Menzil-hücre modeli
N_menzil  = 60;
N_darbe   = 32;
hedef_idx = floor(N_menzil / 2);  % [D5]
pencere   = N_ref_tek_taraf + N_koruma;
% Yavaş-zaman vektörü
t_darbe = (0:N_darbe-1).' / PRF;
% Test hedefi
v_test  = round(v_max * 0.8);
fd_test = 2 * v_test / lam;
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  SIU 2026 - CFAR DEDEKTÖR ANALİZİ v3.1\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');
fprintf('Radar:  fc = %.0f GHz, λ = %.1f cm, PRF = %d Hz\n', fc/1e9, lam*100, PRF);
fprintf('MTI:    Çift İptal Edici [1,-2,1]\n');
fprintf('        Beyaz gürültü analitik kazancı = %.2f dB\n', mti_beyaz_kazanc_dB);
fprintf('CFAR:   N_ref = %d, N_koruma = %d, Pfa_tasarım = %.0e\n', ...
    N_ref_toplam, 2*N_koruma, Pfa_tasarim);
fprintf('Model:  %d menzil hücresi × %d darbe/CPI\n', N_menzil, N_darbe);
fprintf('Hedef:  v = %d m/s, fd = %.0f Hz\n', v_test, fd_test);
fprintf('Tohum:  rng(42)\n\n');
fprintf('[D1] GÜÇ TANIMI:\n');
fprintf('  Termal gürültü:  P_n = 1 (birim referans)\n');
fprintf('  Sinyal gücü:     P_s = SNR_lin × P_n\n');
fprintf('  Jammer gücü:     P_j = JSR_lin × P_s = JSR_lin × SNR_lin × P_n\n');
fprintf('  → JSR = P_j/P_s her zaman sabit tutulur.\n');
fprintf('  Not: Sabit jammer gücü senaryosu bu çalışmada incelenmemiştir.\n');
fprintf('       Menzil hücreleri arası jammer bağımsız modellenmiştir.\n\n');
%% ═══════════════════════════════════════════════════════════════
%  BÖLÜM 1: OTOKORELASYoN ANALİZİ
%  ═══════════════════════════════════════════════════════════════
fprintf('────────────────────────────────────────────────────\n');
fprintf('BÖLÜM 1: Otokorelasyon Analizi\n');
fprintf('────────────────────────────────────────────────────\n');
N_oto     = 512;
N_mc_oto  = 200;
max_gecik = 8;
rho_once  = zeros(n_gurultu, max_gecik);
rho_sonra = zeros(n_gurultu, max_gecik);
for ni = 1:n_gurultu
    alpha = alpha_degeri(ni);
    rp = zeros(1, max_gecik);
    rs = zeros(1, max_gecik);
    for mc = 1:N_mc_oto
        n = generate_colored_noise(N_oto, alpha);
        n = n(:);  % [D6]
        x = abs(n).^2;
        x = x - mean(x);
        vx = sum(x.^2);
        m = filter(mti_koef, 1, n);
        m = m(length(mti_koef):end);
        y = abs(m).^2;
        y = y - mean(y);
        vy = sum(y.^2);
        for gecik = 1:max_gecik
            if vx > eps
                rp(gecik) = rp(gecik) + ...
                    sum(x(1:end-gecik) .* x(gecik+1:end)) / vx;
            end
            if vy > eps
                rs(gecik) = rs(gecik) + ...
                    sum(y(1:end-gecik) .* y(gecik+1:end)) / vy;
            end
        end
    end
    rho_once(ni,:)  = rp / N_mc_oto;
    rho_sonra(ni,:) = rs / N_mc_oto;
end
[max_rho, max_rho_idx] = max(rho_sonra(:,1));
[min_rho, min_rho_idx] = min(rho_sonra(:,1));
fprintf('\nMTI Sonrası Lag-1 Otokorelasyon (güç domeni):\n');
for ni = 1:n_gurultu
    fprintf('  %-12s: ρ_öncesi = %+.3f, ρ_sonrası = %+.3f\n', ...
        gurultu_adi{ni}, rho_once(ni,1), rho_sonra(ni,1));
end
fprintf('  → En yüksek post-MTI ρ₁: %s (%.3f)\n', ...
    gurultu_adi{max_rho_idx}, max_rho);
fprintf('  → En düşük post-MTI ρ₁: %s (%.3f)\n', ...
    gurultu_adi{min_rho_idx}, min_rho);
%% ─── ŞEKİL 1 ───
figure('Position', [60 60 1100 480], 'Color', 'w');
gecikler = 1:max_gecik;
subplot(1,2,1);
set(gca, 'FontName', 'Times New Roman'); % Garantile
for ni = 1:n_gurultu
    plot(gecikler, rho_once(ni,:), 'o-', 'Color', gurultu_renk(ni,:), ...
        'MarkerSize', 5, 'LineWidth', 2, 'DisplayName', gurultu_adi{ni});
    hold on;
end
yline(0, 'k--', 'LineWidth', 2, 'HandleVisibility', 'off');
xlabel('Gecikme (lag)', 'FontName', 'Times New Roman');
ylabel('\rho(lag)', 'FontName', 'Times New Roman');
title('(a) MTI Öncesi', 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend('Location', 'northeast', 'FontSize', 12, 'FontName', 'Times New Roman');
ylim([-0.3 1.0]); grid on; box on;
subplot(1,2,2);
set(gca, 'FontName', 'Times New Roman'); % Garantile
for ni = 1:n_gurultu
    plot(gecikler, rho_sonra(ni,:), 'o-', 'Color', gurultu_renk(ni,:), ...
        'MarkerSize', 5, 'LineWidth', 1.8, 'DisplayName', gurultu_adi{ni});
    hold on;
end
yline(0, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
sinir = 1.96 / sqrt(N_oto);
yline(sinir, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, ...
    'DisplayName', sprintf('Yakl. %%95 ref. (±%.3f)', sinir));  % [D10]
yline(-sinir, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 2, ...
    'HandleVisibility', 'off');
xlabel('Gecikme (lag)', 'FontName', 'Times New Roman');
ylabel('\rho(lag)', 'FontName', 'Times New Roman');
title('(b) MTI Sonrası', 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend('Location', 'northeast', 'FontSize', 12, 'FontName', 'Times New Roman');
ylim([-0.3 1.0]); grid on; box on;
sgtitle('Şekil 1. MTI Öncesi/Sonrası Güç Otokorelasyonu', ...
    'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
exportgraphics(gcf, 'Sekil_01_Otokorelasyon.png', 'Resolution', out_dpi);
fprintf('  ✓ Sekil_01 kaydedildi\n');
%% ═══════════════════════════════════════════════════════════════
%  BÖLÜM 2: PFA SAPMA ANALİZİ
%  ═══════════════════════════════════════════════════════════════
fprintf('\n────────────────────────────────────────────────────\n');
fprintf('BÖLÜM 2: Pfa Sapma Analizi (Pfa_tasarım = %.0e)\n', Pfa_tasarim);
fprintf('────────────────────────────────────────────────────\n');
test_hucre_sayisi = N_menzil - 2*pencere;
fprintf('\nCFAR eşik kalibrasyonu (beyaz gürültü + MTI)...\n');
T_faktor = zeros(1, n_cfar);
N_kal = 1500;
T_UST_SINIR = 50.0;  
for ci = 1:n_cfar
    T_alt = 0.5;
    T_ust = T_UST_SINIR;
    for iter = 1:30
        T_dene = (T_alt + T_ust) / 2;
        fa_sayac = 0;
        toplam_test = 0;
        for trial = 1:N_kal
            jam_2d = complex(zeros(N_menzil, N_darbe));
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, 0);
                jam_2d(r,:) = tmp(:).';
            end
            mti_cikis = mti_filtre_matris(jam_2d, mti_koef);
            guc_menzil = mean(abs(mti_cikis).^2, 2);
            for i = (pencere+1):(N_menzil-pencere)
                ref = cfar_ref_hesapla(guc_menzil, i, ...
                    N_ref_tek_taraf, N_koruma, ci);
                if guc_menzil(i) > T_dene * ref
                    fa_sayac = fa_sayac + 1;
                end
                toplam_test = toplam_test + 1;
            end
        end
        pfa_olculen_kal = fa_sayac / max(toplam_test, 1);
        if pfa_olculen_kal > Pfa_tasarim
            T_alt = T_dene;
        else
            T_ust = T_dene;
        end
    end
    T_faktor(ci) = (T_alt + T_ust) / 2;
    if T_faktor(ci) > 0.95 * T_UST_SINIR
        warning('%s: T = %.2f üst sınıra çok yakın! T_UST_SINIR artırılmalı.', ...
            cfar_adi{ci}, T_faktor(ci));
    end
end
fprintf('\nKalibrasyon doğrulama (T_faktor ile gerçekleşen Pfa):\n');
N_dogrulama = 1200;
for ci = 1:n_cfar
    fa_s = 0; top_s = 0;
    for trial = 1:N_dogrulama
        jam_2d = complex(zeros(N_menzil, N_darbe));
        for r = 1:N_menzil
            tmp = generate_colored_noise(N_darbe, 0);
            jam_2d(r,:) = tmp(:).';
        end
        mti_cikis = mti_filtre_matris(jam_2d, mti_koef);
        guc = mean(abs(mti_cikis).^2, 2);
        for i = (pencere+1):(N_menzil-pencere)
            ref = cfar_ref_hesapla(guc, i, N_ref_tek_taraf, N_koruma, ci);
            if guc(i) > T_faktor(ci) * ref
                fa_s = fa_s + 1;
            end
            top_s = top_s + 1;
        end
    end
    pfa_dogrulama = fa_s / top_s;
    fprintf('  %s: T = %.4f, Pfa = %.2e (oran: %.2f×)\n', ...
        cfar_adi{ci}, T_faktor(ci), pfa_dogrulama, pfa_dogrulama/Pfa_tasarim);
end
fprintf('\nPfa ölçümü başlıyor...\n');
N_trial_pfa = 2000;
fprintf('  %d trial × %d hücre = %d test/koşul\n', ...
    N_trial_pfa, test_hucre_sayisi, N_trial_pfa*test_hucre_sayisi);
fprintf('  Beklenen FA (Pfa=%.0e): ≈ %d — Monte Carlo tahmini\n', ...
    Pfa_tasarim, round(Pfa_tasarim * N_trial_pfa * test_hucre_sayisi));
Pfa_olculen = zeros(n_cfar, n_gurultu);
for ci = 1:n_cfar
    T = T_faktor(ci);
    for ni = 1:n_gurultu
        alpha = alpha_degeri(ni);
        fa_sayac = 0;
        toplam_test = 0;
        for trial = 1:N_trial_pfa
            jam_2d = complex(zeros(N_menzil, N_darbe));
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, alpha);
                jam_2d(r,:) = tmp(:).';
            end
            mti_cikis = mti_filtre_matris(jam_2d, mti_koef);
            guc_menzil = mean(abs(mti_cikis).^2, 2);
            for i = (pencere+1):(N_menzil-pencere)
                ref = cfar_ref_hesapla(guc_menzil, i, ...
                    N_ref_tek_taraf, N_koruma, ci);
                if guc_menzil(i) > T * ref
                    fa_sayac = fa_sayac + 1;
                end
                toplam_test = toplam_test + 1;
            end
        end
        Pfa_olculen(ci, ni) = fa_sayac / max(toplam_test, 1);
    end
    fprintf('  %s tamamlandı\n', cfar_adi{ci});
end
pfa_oran = Pfa_olculen / Pfa_tasarim;
fprintf('\n┌────────────────────────────────────────────────────────────────┐\n');
fprintf('│           PFA SAPMA TABLOSU (Ölçülen / Tasarım)              │\n');
fprintf('│                    Tasarım Pfa = %.0e                        │\n', Pfa_tasarim);
fprintf('├───────────┬──────────────┬──────────────┬──────────────┬──────────────┤\n');
fprintf('│ CFAR      │    Beyaz     │    Pembe     │  Kahverengi  │    Mavi      │\n');
fprintf('├───────────┼──────────────┼──────────────┼──────────────┼──────────────┤\n');
pfa_ust_sinir = 1 / (N_trial_pfa * test_hucre_sayisi);
for ci = 1:n_cfar
    fprintf('│ %-9s │', cfar_adi{ci});
    for ni = 1:n_gurultu
        pfa = Pfa_olculen(ci, ni);
        oran = pfa_oran(ci, ni);
        if pfa < pfa_ust_sinir
            fprintf(' <%.1e(<%.2fx)│', pfa_ust_sinir, pfa_ust_sinir/Pfa_tasarim);
        else
            fprintf(' %5.1e(%4.0fx)│', pfa, oran);
        end
    end
    fprintf('\n');
end
fprintf('└───────────┴──────────────┴──────────────┴──────────────┴──────────────┘\n');
[max_sapma_val, max_sapma_lin] = max(pfa_oran(:));
[max_sapma_ci, max_sapma_ni] = ind2sub(size(pfa_oran), max_sapma_lin);
fprintf('En büyük Pfa sapması: %s + %s → %.0f×\n', ...
    cfar_adi{max_sapma_ci}, gurultu_adi{max_sapma_ni}, max_sapma_val);
%% ─── ŞEKİL 2 ───
figure('Position', [80 80 820 500], 'Color', 'w');
set(gca, 'FontName', 'Times New Roman'); % Garantile
pfa_oran_log = log10(max(pfa_oran, 0.1));
imagesc(pfa_oran_log);
colormap(jet);
cb = colorbar;
cb.FontName = 'Times New Roman';
cb.Ticks = [-1 0 1 2 3];
cb.TickLabels = {'0.1×', '1×', '10×', '100×', '1000×'};
cb.Label.String = 'Pfa Oranı (Ölçülen / Tasarım)';
cb.Label.FontWeight = 'bold';
cb.Label.FontName = 'Times New Roman';
set(gca, 'XTick', 1:n_gurultu, 'XTickLabel', gurultu_adi, 'FontName', 'Times New Roman');
set(gca, 'YTick', 1:n_cfar, 'YTickLabel', cfar_adi, 'FontName', 'Times New Roman');
xlabel('Gürültü Tipi', 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('CFAR Türü', 'FontWeight', 'bold', 'FontName', 'Times New Roman');
for ci = 1:n_cfar
    for ni = 1:n_gurultu
        oran = pfa_oran(ci, ni);
        if Pfa_olculen(ci,ni) < pfa_ust_sinir
            renk = 'w';  
            metin = sprintf('<%.3f×\n(<%.1e)', pfa_ust_sinir/Pfa_tasarim, pfa_ust_sinir);
        else
            if oran > 50, renk = 'k'; else, renk = 'k'; end
            metin = sprintf('%.1f×\n(%.1e)', oran, Pfa_olculen(ci,ni));
        end
        text(ni, ci, metin, 'HorizontalAlignment', 'center', ...
            'FontSize', 18, 'FontWeight', 'bold', 'Color', renk, 'FontName', 'Times New Roman');
    end
end
title(sprintf('Şekil 2. Pfa Sapması (Tasarım Pfa = %.0e)', Pfa_tasarim), ...
    'FontWeight', 'bold', 'FontName', 'Times New Roman');
grid off; box on;
exportgraphics(gcf, 'Sekil_02_Pfa_Sapma.png', 'Resolution', out_dpi);
fprintf('  ✓ Sekil_02 kaydedildi\n');
%% ═══════════════════════════════════════════════════════════════
%  BÖLÜM 3: Pd vs SNR + GERÇEKLEŞen Pfa
%  ═══════════════════════════════════════════════════════════════
fprintf('\n────────────────────────────────────────────────────\n');
fprintf('BÖLÜM 3: Pd vs SNR + Gerçekleşen Pfa\n');
fprintf('────────────────────────────────────────────────────\n');
SNR_araligi_dB = -10:3:30;
N_mc_pd     = 200;
JSR_sabit   = 10;
JSR_sabit_lin = 10^(JSR_sabit / 10);
n_snr  = length(SNR_araligi_dB);
Pd_snr = zeros(n_gurultu, n_snr);
Pd_ref = zeros(1, n_snr);
Pfa_gercek = zeros(n_gurultu, n_snr);
N_mc_pfa_kontrol = 400;  
fprintf('Hedef: v = %d m/s, fd = %.0f Hz\n', v_test, fd_test);
fprintf('JSR = %d dB (sabit-JSR senaryosu), CA-CFAR\n', JSR_sabit);
for ni = 1:n_gurultu
    alpha = alpha_degeri(ni);
    for si = 1:n_snr
        snr_lin = 10^(SNR_araligi_dB(si) / 10);
        jam_guc = JSR_sabit_lin * snr_lin;  
        tespit = 0;
        for mc = 1:N_mc_pd
            veri = complex(zeros(N_menzil, N_darbe));  
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, alpha);
                veri(r,:) = tmp(:).' * sqrt(jam_guc) + ...
                    (randn(1,N_darbe)+1j*randn(1,N_darbe))/sqrt(2);
            end
            veri(hedef_idx,:) = veri(hedef_idx,:) + ...
                sqrt(snr_lin) * exp(1j*2*pi*fd_test*t_darbe).';
            mti_cikis = mti_filtre_matris(veri, mti_koef);
            guc = mean(abs(mti_cikis).^2, 2);
            ref = cfar_ref_hesapla(guc, hedef_idx, N_ref_tek_taraf, N_koruma, 1);
            if guc(hedef_idx) > T_faktor(1) * ref
                tespit = tespit + 1;
            end
        end
        Pd_snr(ni, si) = tespit / N_mc_pd;
        fa_sayac = 0;
        top_test = 0;
        for mc = 1:N_mc_pfa_kontrol
            veri = complex(zeros(N_menzil, N_darbe));
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, alpha);
                veri(r,:) = tmp(:).' * sqrt(jam_guc) + ...
                    (randn(1,N_darbe)+1j*randn(1,N_darbe))/sqrt(2);
            end
            mti_cikis = mti_filtre_matris(veri, mti_koef);
            guc = mean(abs(mti_cikis).^2, 2);
            for i = (pencere+1):(N_menzil-pencere)
                ref = cfar_ref_hesapla(guc, i, N_ref_tek_taraf, N_koruma, 1);
                if guc(i) > T_faktor(1) * ref
                    fa_sayac = fa_sayac + 1;
                end
                top_test = top_test + 1;
            end
        end
        Pfa_gercek(ni, si) = fa_sayac / max(top_test, 1);
    end
    fprintf('  %s tamamlandı (Pd + Pfa kontrol)\n', gurultu_adi{ni});
end
for si = 1:n_snr
    snr_lin = 10^(SNR_araligi_dB(si) / 10);
    tespit = 0;
    for mc = 1:N_mc_pd
        veri = complex(zeros(N_menzil, N_darbe));
        for r = 1:N_menzil
            veri(r,:) = (randn(1,N_darbe)+1j*randn(1,N_darbe))/sqrt(2);
        end
        veri(hedef_idx,:) = veri(hedef_idx,:) + ...
            sqrt(snr_lin) * exp(1j*2*pi*fd_test*t_darbe).';
        mti_cikis = mti_filtre_matris(veri, mti_koef);
        guc = mean(abs(mti_cikis).^2, 2);
        ref = cfar_ref_hesapla(guc, hedef_idx, N_ref_tek_taraf, N_koruma, 1);
        if guc(hedef_idx) > T_faktor(1) * ref
            tespit = tespit + 1;
        end
    end
    Pd_ref(si) = tespit / N_mc_pd;
end
fprintf('  Karıştırıcısız referans tamamlandı\n');
fprintf('\n[D11] Gerçekleşen Pfa (CA-CFAR, hedefsiz, SNR noktaları boyunca):\n');
fprintf('  %-12s  %10s  %10s  %10s\n', 'Gürültü', 'Ort.', 'Min.', 'Maks.');
fprintf('  ────────────────────────────────────────────────\n');
for ni = 1:n_gurultu
    ort_pfa = mean(Pfa_gercek(ni,:));
    min_pfa = min(Pfa_gercek(ni,:));
    max_pfa = max(Pfa_gercek(ni,:));
    fprintf('  %-12s  %10.2e  %10.2e  %10.2e  (ort: %.1f×)\n', ...
        gurultu_adi{ni}, ort_pfa, min_pfa, max_pfa, ort_pfa/Pfa_tasarim);
end
%% Ortak stil ayarları
lw_main   = 2.2;                 
lw_ref    = 1.4;                 
ms_main   = 5;                   
fs_axis   = 24;
fs_title  = 14;
fs_legend = 24;
ref_col   = [0.55 0.55 0.55];
grid_col  = [0.82 0.82 0.82];
%% ─── ŞEKİL 3: Pd vs SNR ───
fig1 = figure('Position', [60 60 900 560], 'Color', 'w');
ax1 = axes(fig1);
hold(ax1, 'on');
ax1.FontName = 'Times New Roman';
plot(ax1, SNR_araligi_dB, Pd_ref, 'k--', ...
    'LineWidth', 2.6, ...
    'DisplayName', 'Karıştırıcısız ortam');
for ni = 1:n_gurultu
    plot(ax1, SNR_araligi_dB, Pd_snr(ni,:), 'o-', ...
        'Color', gurultu_renk(ni,:), ...
        'MarkerSize', ms_main, ...
        'LineWidth', lw_main, ...
        'DisplayName', sprintf('%s (\\alpha=%d)', ...
        gurultu_adi{ni}, alpha_degeri(ni)));
end
yline(ax1, 0.9, ':', 'Color', ref_col, ...
    'LineWidth', lw_ref, 'HandleVisibility', 'off');
yline(ax1, 0.5, ':', 'Color', ref_col, ...
    'LineWidth', lw_ref, 'HandleVisibility', 'off');
x_left = min(SNR_araligi_dB) + 0.8;
text(ax1, x_left, 0.915, 'P_d = 0.9', ...
    'FontSize', 16, 'Color', ref_col, ...
    'VerticalAlignment', 'bottom', 'FontName', 'Times New Roman');
text(ax1, x_left, 0.515, 'P_d = 0.5', ...
    'FontSize', 16, 'Color', ref_col, ...
    'VerticalAlignment', 'bottom', 'FontName', 'Times New Roman');
xlabel(ax1, 'SNR (dB)','FontSize', 18, 'FontName', 'Times New Roman');
ylabel(ax1, 'Tespit Olasılığı, P_d','FontSize', 18, 'FontName', 'Times New Roman');
xlim(ax1, [min(SNR_araligi_dB) max(SNR_araligi_dB)]);
ylim(ax1, [0 1.05]);
grid(ax1, 'on');
box(ax1, 'on');
ax1.LineWidth = 1.1;
ax1.FontSize = 24;
ax1.GridColor = grid_col;
ax1.GridAlpha = 0.9;
ax1.MinorGridAlpha = 0.35;
ax1.Layer = 'top';
legend(ax1, 'Location', 'east', ...
    'FontSize', 24, ...
    'Box', 'on', ...
    'Color', 'w', 'FontName', 'Times New Roman');
exportgraphics(fig1, 'Sekil_03_Pd_SNR.pdf', 'ContentType', 'vector');
exportgraphics(fig1, 'Sekil_03_Pd_SNR.png', 'Resolution', out_dpi);
fprintf('  ✓ Sekil_03 kaydedildi\n');
%% ─── ŞEKİL 3b: Gerçekleşen Pfa vs SNR ───
fig2 = figure('Position', [60 60 900 560], 'Color', 'w');
ax2 = axes(fig2);
hold(ax2, 'on');
ax2.FontName = 'Times New Roman';
pfa_olcum_tabani = 1 / (N_mc_pfa_kontrol * test_hucre_sayisi);
for ni = 1:n_gurultu
    pfa_gosterim = Pfa_gercek(ni,:);
    pfa_gosterim(pfa_gosterim < pfa_olcum_tabani) = pfa_olcum_tabani;
    semilogy(ax2, SNR_araligi_dB, pfa_gosterim, 'o-', ...
        'Color', gurultu_renk(ni,:), ...
        'MarkerSize', ms_main-1, ...
        'LineWidth', lw_main, ...
        'DisplayName', sprintf('%s (\\alpha=%d)', ...
        gurultu_adi{ni}, alpha_degeri(ni)));
end
yline(ax2, Pfa_tasarim, 'k--', ...
    'LineWidth', 2.2, ...
    'DisplayName', sprintf('Tasarlanan P_{fa} = %.0e', Pfa_tasarim));
xlabel(ax2, 'SNR (dB)','FontSize', 18, 'FontName', 'Times New Roman');
ylabel(ax2, 'Yanlış Alarm Oranı, P_{fa}','FontSize', 18, 'FontName', 'Times New Roman');
xlim(ax2, [min(SNR_araligi_dB) max(SNR_araligi_dB)]);
ylim(ax2, [pfa_olcum_tabani 1e-1]);
grid(ax2, 'on');
box(ax2, 'on');
ax2.LineWidth = 1.1;
ax2.FontSize = fs_axis;
ax2.GridColor = grid_col;
ax2.GridAlpha = 0.9;
ax2.MinorGridAlpha = 0.35;
ax2.Layer = 'top';
ax2.YScale = 'log';
legend(ax2, 'Location', 'southeast', ...
    'FontSize', 18, ...
    'Box', 'on', ...
    'Color', 'w', 'FontName', 'Times New Roman');
exportgraphics(fig2, 'Sekil_03b_Pfa_Kontrol.pdf', 'ContentType', 'vector');
exportgraphics(fig2, 'Sekil_03b_Pfa_Kontrol.png', 'Resolution', out_dpi);
fprintf('  ✓ Sekil_03b kaydedildi\n');
%% ═══════════════════════════════════════════════════════════════
%  BÖLÜM 4: Pd vs JSR
%  ═══════════════════════════════════════════════════════════════
fprintf('\n────────────────────────────────────────────────────\n');
fprintf('BÖLÜM 4: Pd vs JSR\n');
fprintf('────────────────────────────────────────────────────\n');
JSR_araligi_dB = 0:3:24;
SNR_sabit_dB   = 15;
SNR_sabit_lin  = 10^(SNR_sabit_dB / 10);
N_mc_jsr       = 200;
n_jsr  = length(JSR_araligi_dB);
Pd_jsr = zeros(n_gurultu, n_jsr);
fprintf('SNR = %d dB (sabit), v = %d m/s, CA-CFAR\n', SNR_sabit_dB, v_test);
for ni = 1:n_gurultu
    alpha = alpha_degeri(ni);
    for ji = 1:n_jsr
        jsr_lin = 10^(JSR_araligi_dB(ji) / 10);
        jam_guc = jsr_lin * SNR_sabit_lin;  
        tespit = 0;
        for mc = 1:N_mc_jsr
            veri = complex(zeros(N_menzil, N_darbe));
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, alpha);
                veri(r,:) = tmp(:).' * sqrt(jam_guc) + ...
                    (randn(1,N_darbe)+1j*randn(1,N_darbe))/sqrt(2);
            end
            veri(hedef_idx,:) = veri(hedef_idx,:) + ...
                sqrt(SNR_sabit_lin) * exp(1j*2*pi*fd_test*t_darbe).';
            mti_cikis = mti_filtre_matris(veri, mti_koef);
            guc = mean(abs(mti_cikis).^2, 2);
            ref = cfar_ref_hesapla(guc, hedef_idx, N_ref_tek_taraf, N_koruma, 1);
            if guc(hedef_idx) > T_faktor(1) * ref
                tespit = tespit + 1;
            end
        end
        Pd_jsr(ni, ji) = tespit / N_mc_jsr;
    end
    fprintf('  %s tamamlandı\n', gurultu_adi{ni});
end
%% ─── ŞEKİL 4: Pd vs JSR ───
fig4 = figure('Position', [60 60 900 560], 'Color', 'w');
ax4 = axes(fig4);
hold(ax4, 'on');
ax4.FontName = 'Times New Roman';
for ni = 1:n_gurultu
    plot(ax4, JSR_araligi_dB, Pd_jsr(ni,:), 'o-', ...
        'Color', gurultu_renk(ni,:), ...
        'MarkerSize', ms_main, ...
        'LineWidth', lw_main, ...
        'DisplayName', sprintf('%s (\\alpha=%d)', ...
        gurultu_adi{ni}, alpha_degeri(ni)));
end
yline(ax4, 0.9, ':', 'Color', ref_col, ...
    'LineWidth', lw_ref, 'HandleVisibility', 'off');
yline(ax4, 0.5, ':', 'Color', ref_col, ...
    'LineWidth', lw_ref, 'HandleVisibility', 'off');
x_left = min(JSR_araligi_dB) + 0.8;
text(ax4, x_left, 0.915, 'P_d = 0.9', ...
    'FontSize', 10, 'Color', ref_col, ...
    'VerticalAlignment', 'bottom', 'FontName', 'Times New Roman');
text(ax4, x_left, 0.515, 'P_d = 0.5', ...
    'FontSize', 10, 'Color', ref_col, ...
    'VerticalAlignment', 'bottom', 'FontName', 'Times New Roman');
xlabel(ax4, 'JSR (dB)', 'FontSize', 18, 'FontName', 'Times New Roman');
ylabel(ax4, 'Tespit Olasılığı, P_d','FontSize', 18, 'FontName', 'Times New Roman');
xlim(ax4, [min(JSR_araligi_dB) max(JSR_araligi_dB)]);
ylim(ax4, [0 1.05]);
grid(ax4, 'on');
box(ax4, 'on');
ax4.LineWidth = 1.1;
ax4.FontSize = fs_axis;
ax4.GridColor = grid_col;
ax4.GridAlpha = 0.9;
ax4.MinorGridAlpha = 0.35;
ax4.Layer = 'top';
legend(ax4, 'Location', 'east', ...
    'FontSize', 24, ...
    'Box', 'on', ...
    'Color', 'w', 'FontName', 'Times New Roman');
exportgraphics(fig4, 'Sekil_04_Pd_JSR.pdf', 'ContentType', 'vector');
exportgraphics(fig4, 'Sekil_04_Pd_JSR.png', 'Resolution', out_dpi);
fprintf('  ✓ Sekil_04 kaydedildi\n');
%% ═══════════════════════════════════════════════════════════════
%  BÖLÜM 5: Pd vs Hedef Hızı
%  ═══════════════════════════════════════════════════════════════
fprintf('\n────────────────────────────────────────────────────\n');
fprintf('BÖLÜM 5: Pd vs Hız\n');
fprintf('────────────────────────────────────────────────────\n');
v_tarama   = [0.5, 1, 2, 3, 5, 8, 12, 16, 20, 24, 28, 32, 35];
JSR_hiz    = 10;   JSR_hiz_lin = 10^(JSR_hiz/10);
SNR_hiz    = 13;   SNR_hiz_lin = 10^(SNR_hiz/10);
N_mc_hiz   = 150;
jam_guc_hiz = JSR_hiz_lin * SNR_hiz_lin; 
n_hiz  = length(v_tarama);
Pd_hiz = zeros(n_gurultu, n_hiz);
fprintf('SNR = %d dB, JSR = %d dB, CA-CFAR\n', SNR_hiz, JSR_hiz);
fprintf('Hız noktaları: [%s] m/s\n', num2str(v_tarama, '%.1f '));
for ni = 1:n_gurultu
    alpha = alpha_degeri(ni);
    for vi = 1:n_hiz
        fd = 2 * v_tarama(vi) / lam;
        tespit = 0;
        for mc = 1:N_mc_hiz
            veri = complex(zeros(N_menzil, N_darbe));
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, alpha);
                veri(r,:) = tmp(:).' * sqrt(jam_guc_hiz) + ...
                    (randn(1,N_darbe)+1j*randn(1,N_darbe))/sqrt(2);
            end
            veri(hedef_idx,:) = veri(hedef_idx,:) + ...
                sqrt(SNR_hiz_lin) * exp(1j*2*pi*fd*t_darbe).';
            mti_cikis = mti_filtre_matris(veri, mti_koef);
            guc = mean(abs(mti_cikis).^2, 2);
            ref = cfar_ref_hesapla(guc, hedef_idx, N_ref_tek_taraf, N_koruma, 1);
            if guc(hedef_idx) > T_faktor(1) * ref
                tespit = tespit + 1;
            end
        end
        Pd_hiz(ni, vi) = tespit / N_mc_hiz;
    end
    fprintf('  %s tamamlandı\n', gurultu_adi{ni});
end
%% ─── ŞEKİL 5 ───
figure('Position', [60 60 900 560], 'Color', 'w');
set(gca, 'FontName', 'Times New Roman'); % Garantile
for ni = 1:n_gurultu
    plot(v_tarama, Pd_hiz(ni,:), 'o-', 'Color', gurultu_renk(ni,:), ...
        'MarkerSize', 5, 'LineWidth', 3.5, ...
        'DisplayName', sprintf('%s (\\alpha=%+d)', gurultu_adi{ni}, alpha_degeri(ni)));
    hold on;
end
yline(0.9, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 3.5, 'HandleVisibility', 'off');
yline(0.5, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 3.5, 'HandleVisibility', 'off');
w_notch = linspace(0, pi, 1000);
H_notch = freqz(mti_koef, 1, w_notch);
H_pow_notch = abs(H_notch).^2;
f_norm_notch = w_notch / (2*pi); 
v_notch_all = f_norm_notch * PRF * lam / 2;  
idx_notch = find(H_pow_notch >= 1.0, 1, 'first');
if ~isempty(idx_notch)
    v_notch_sinir = v_notch_all(idx_notch);
else
    v_notch_sinir = 3; 
end
patch([0 v_notch_sinir v_notch_sinir 0], [-0.02 -0.02 1.05 1.05], ...
    [1 0.9 0.9], 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
text(v_notch_sinir/2, 0.08, sprintf('MTI düşük-kazanç\nbölgesi (< %.1f m/s)', v_notch_sinir), ...
    'FontSize', 9, 'Color', [0.7 0 0], 'HorizontalAlignment', 'center', 'FontName', 'Times New Roman');
xlabel('Hedef Radyal Hızı, v_r (m/s)', 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Dedeksiyon Olasılığı, P_d', 'FontWeight', 'bold', 'FontName', 'Times New Roman');
title(sprintf('Şekil 5. P_d - Hedef Hızı (SNR = %d dB, JSR = %d dB, CA-CFAR)', ...
    SNR_hiz, JSR_hiz), 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend('Location', 'southeast', 'FontSize', 12, 'FontName', 'Times New Roman');
ylim([-0.02 1.05]); xlim([0 v_max]); grid on; box on;
exportgraphics(gcf, 'Sekil_05_Pd_Hiz.png', 'Resolution', out_dpi);
fprintf('  ✓ Sekil_05 kaydedildi\n');
%% ═══════════════════════════════════════════════════════════════
%  BÖLÜM 6: CFAR TÜRÜ DAYANIKLILIĞI (Mavi Gürültü)
%  ═══════════════════════════════════════════════════════════════
fprintf('\n────────────────────────────────────────────────────\n');
fprintf('BÖLÜM 6: CFAR Dayanıklılık Karşılaştırması (Mavi Gürültü)\n');
fprintf('────────────────────────────────────────────────────\n');
N_mc_kars = 150;
Pd_cfar_mavi = zeros(n_cfar, n_jsr);
fprintf('Mavi gürültü (α=-1), SNR = %d dB, v = %d m/s\n', SNR_sabit_dB, v_test);
for ci = 1:n_cfar
    T = T_faktor(ci);
    for ji = 1:n_jsr
        jsr_lin = 10^(JSR_araligi_dB(ji) / 10);
        jam_guc = jsr_lin * SNR_sabit_lin;  
        tespit = 0;
        for mc = 1:N_mc_kars
            veri = complex(zeros(N_menzil, N_darbe));
            for r = 1:N_menzil
                tmp = generate_colored_noise(N_darbe, -1);
                veri(r,:) = tmp(:).' * sqrt(jam_guc) + ...
                    (randn(1,N_darbe)+1j*randn(1,N_darbe))/sqrt(2);
            end
            veri(hedef_idx,:) = veri(hedef_idx,:) + ...
                sqrt(SNR_sabit_lin) * exp(1j*2*pi*fd_test*t_darbe).';
            mti_cikis = mti_filtre_matris(veri, mti_koef);
            guc = mean(abs(mti_cikis).^2, 2);
            ref = cfar_ref_hesapla(guc, hedef_idx, N_ref_tek_taraf, N_koruma, ci);
            if guc(hedef_idx) > T * ref
                tespit = tespit + 1;
            end
        end
        Pd_cfar_mavi(ci, ji) = tespit / N_mc_kars;
    end
    fprintf('  %s tamamlandı\n', cfar_adi{ci});
end
%% ─── ŞEKİL 6: Mavi gürültü altında CFAR karşılaştırması ───
fig6 = figure('Position', [60 60 900 560], 'Color', 'w');
ax6 = axes(fig6);
hold(ax6, 'on');
ax6.FontName = 'Times New Roman';
cfar_renk = [0.00 0.35 0.70;   
             0.20 0.65 0.20;   
             0.85 0.35 0.00;   
             0.50 0.45 0.80];  
cfar_isaret = {'o', 's', '^', 'd'};
cfar_stil   = {'-', '--', '-', ':'};
lw_main = 2.8;
ms_main = 7;
lw_ref  = 1.2;
ref_col = [0.60 0.60 0.60];
for ci = 1:n_cfar
    plot(ax6, JSR_araligi_dB, Pd_cfar_mavi(ci,:), ...
        'LineStyle', cfar_stil{ci}, ...
        'Marker', cfar_isaret{ci}, ...
        'Color', cfar_renk(ci,:), ...
        'MarkerSize', ms_main, ...
        'LineWidth', lw_main, ...
        'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', cfar_renk(ci,:), ...
        'DisplayName', cfar_adi{ci});
end
yline(ax6, 0.9, ':', 'Color', ref_col, ...
    'LineWidth', lw_ref, 'HandleVisibility', 'off');
yline(ax6, 0.5, ':', 'Color', ref_col, ...
    'LineWidth', lw_ref, 'HandleVisibility', 'off');
x_left = min(JSR_araligi_dB) + 0.8;
text(ax6, x_left, 0.915, 'P_d = 0.9', ...
    'FontSize', 13, 'Color', ref_col, ...
    'VerticalAlignment', 'bottom', 'FontName', 'Times New Roman');
text(ax6, x_left, 0.515, 'P_d = 0.5', ...
    'FontSize', 13, 'Color', ref_col, ...
    'VerticalAlignment', 'bottom', 'FontName', 'Times New Roman');
xlabel(ax6, 'JSR (dB)', 'FontSize', 24, 'FontName', 'Times New Roman');
ylabel(ax6, 'Tespit Olasılığı, P_d', 'FontSize', 24, 'FontName', 'Times New Roman');
xlim(ax6, [min(JSR_araligi_dB) max(JSR_araligi_dB)]);
ylim(ax6, [0 1.05]);
ax6.Color = 'w';
grid(ax6, 'on');
box(ax6, 'on');
ax6.LineWidth = 1.1;
ax6.FontSize = 24;
ax6.GridColor = [0.82 0.82 0.82];
ax6.GridAlpha = 0.35;
ax6.Layer = 'top';
legend(ax6, 'Location', 'east', ...
    'FontSize', 22, ...
    'Box', 'on', ...
    'Color', 'w', 'FontName', 'Times New Roman');
exportgraphics(fig6, 'Sekil_06_CFAR_Karsilastirma.pdf', 'ContentType', 'vector');
exportgraphics(fig6, 'Sekil_06_CFAR_Karsilastirma.png', 'Resolution', out_dpi);
%% ═══════════════════════════════════════════════════════════════
%  ÖZET 
%  ═══════════════════════════════════════════════════════════════
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  ANA BULGULAR\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
% ... Kodun kalan metin dökümleri aynı ...
% (Buradaki fprintf'ler command window çıktısı olduğu için Times New Roman vs. uygulanmaz)
for ni = 1:n_gurultu
    fprintf('   %-12s: %+.3f\n', gurultu_adi{ni}, rho_sonra(ni,1));
end
[~, eyuk] = max(rho_sonra(:,1));
[~, edus] = min(rho_sonra(:,1));
fprintf('   → En yüksek: %s, En düşük: %s\n', gurultu_adi{eyuk}, gurultu_adi{edus});
fprintf('\n2. PFA SAPMASI (CA-CFAR, Pfa_tasarım = %.0e):\n', Pfa_tasarim);
for ni = 1:n_gurultu
    pfa = Pfa_olculen(1, ni);
    if pfa < pfa_ust_sinir
        fprintf('   %-12s: <%.1e (<%.3f×)\n', gurultu_adi{ni}, pfa_ust_sinir, pfa_ust_sinir/Pfa_tasarim);
    else
        fprintf('   %-12s: %.2e (%.0f×)\n', gurultu_adi{ni}, pfa, pfa_oran(1,ni));
    end
end
pfa_ust_oran = pfa_ust_sinir / Pfa_tasarim;
for ni_t = [3, 4]
    sutun_oranlari = pfa_oran(:, ni_t);
    min_oran = min(sutun_oranlari);
    esit_idx = find(sutun_oranlari == min_oran);
    if all(sutun_oranlari < pfa_ust_oran)
        fprintf('   %s: Tüm CFAR türlerinde Pfa < %.1e (ayırt edilemez)\n', ...
            gurultu_adi{ni_t}, pfa_ust_sinir);
    elseif length(esit_idx) > 1
        isimler = strjoin(cfar_adi(esit_idx), ', ');
        fprintf('   %s en düşük Pfa sapması: %s (%.0f×, berabere)\n', ...
            gurultu_adi{ni_t}, isimler, min_oran);
    else
        if min_oran > 10
            fprintf('   %s en düşük Pfa sapması: %s (%.0f×, yine de yüksek)\n', ...
                gurultu_adi{ni_t}, cfar_adi{esit_idx}, min_oran);
        else
            fprintf('   %s en düşük Pfa sapması: %s (%.0f×)\n', ...
                gurultu_adi{ni_t}, cfar_adi{esit_idx}, min_oran);
        end
    end
end
fprintf('\n3. GERÇEKLEŞen Pfa (CA-CFAR, hedefsiz kontrol):\n');
for ni = 1:n_gurultu
    ort_pfa = mean(Pfa_gercek(ni,:));
    max_pfa = max(Pfa_gercek(ni,:));
    fprintf('   %-12s: ort=%.2e (%.1f×), maks=%.2e (%.1f×)\n', ...
        gurultu_adi{ni}, ort_pfa, ort_pfa/Pfa_tasarim, ...
        max_pfa, max_pfa/Pfa_tasarim);
end
fprintf('\n4. SNR KAYBI (Pd=0.5, JSR=%d dB):\n', JSR_sabit);
idx_ref = find(Pd_ref >= 0.5, 1, 'first');
if ~isempty(idx_ref), snr_ref = SNR_araligi_dB(idx_ref);
else, snr_ref = NaN; end
snr_50 = inf(1, n_gurultu);
for ni = 1:n_gurultu
    idx_n = find(Pd_snr(ni,:) >= 0.5, 1, 'first');
    if ~isempty(idx_n) && ~isnan(snr_ref)
        snr_50(ni) = SNR_araligi_dB(idx_n);
        kayip = snr_50(ni) - snr_ref;
        fprintf('   %-12s: SNR@Pd=0.5 ≈ %+d dB (kayıp ≈ %+d dB)\n', ...
            gurultu_adi{ni}, snr_50(ni), kayip);
    else
        fprintf('   %-12s: Pd < 0.5 tüm aralıkta (>%d dB kayıp)\n', ...
            gurultu_adi{ni}, SNR_araligi_dB(end) - snr_ref);
    end
end
ulasamayan = find(isinf(snr_50));
ulasan = find(~isinf(snr_50));
if ~isempty(ulasan)
    if length(ulasan) == 1
        fprintf('   → Ölçülen SNR aralığında Pd=0.5''e ulaşabilen tek tip: %s\n', ...
            gurultu_adi{ulasan});
    else
        isimler = strjoin(gurultu_adi(ulasan), ', ');
        [~, en_gec_rel] = max(snr_50(ulasan));
        fprintf('   → Pd=0.5''e ulaşan tipler: %s (en geç: %s)\n', ...
            isimler, gurultu_adi{ulasan(en_gec_rel)});
    end
end
if ~isempty(ulasamayan)
    isimler = strjoin(gurultu_adi(ulasamayan), ', ');
    fprintf('   → Pd=0.5''e hiç ulaşamayan: %s\n', isimler);
end
fprintf('\n5. JSR TOLERANSI (Pd≥0.5, SNR=%d dB):\n', SNR_sabit_dB);
jsr_tol = -inf(1, n_gurultu);
for ni = 1:n_gurultu
    idx_j = find(Pd_jsr(ni,:) >= 0.5, 1, 'last');
    if ~isempty(idx_j)
        jsr_tol(ni) = JSR_araligi_dB(idx_j);
        fprintf('   %-12s: Maks JSR ≈ %+d dB\n', gurultu_adi{ni}, jsr_tol(ni));
    else
        fprintf('   %-12s: Pd < 0.5 tüm JSR aralığında\n', gurultu_adi{ni});
    end
end
jsr_sonlu_idx = find(~isinf(jsr_tol));
jsr_inf_idx = find(isinf(jsr_tol));
if ~isempty(jsr_sonlu_idx)
    jsr_sonlu = jsr_tol(jsr_sonlu_idx);
    min_tol = min(jsr_sonlu);
    esit_etkili = jsr_sonlu_idx(jsr_sonlu == min_tol);
    if length(esit_etkili) > 1
        isimler = strjoin(gurultu_adi(esit_etkili), ', ');
        fprintf('   → Pd≥0.5 sağlayabilen tipler arasında en düşük JSR toleransı: %s (%+d dB, berabere)\n', isimler, min_tol);
    else
        fprintf('   → Pd≥0.5 sağlayabilen tipler arasında en düşük JSR toleransı: %s (%+d dB)\n', gurultu_adi{esit_etkili}, min_tol);
    end
end
if ~isempty(jsr_inf_idx)
    isimler = strjoin(gurultu_adi(jsr_inf_idx), ', ');
    fprintf('   → Hiçbir JSR noktasında Pd≥0.5 sağlayamayan: %s\n', isimler);
end
fprintf('\n6. HIZ KAPSAMASI (Pd≥0.5, SNR=%d, JSR=%d dB):\n', SNR_hiz, JSR_hiz);
kapsam = zeros(1, n_gurultu);
for ni = 1:n_gurultu
    tespit_v = v_tarama(Pd_hiz(ni,:) >= 0.5);
    kapsam(ni) = length(tespit_v);
    if ~isempty(tespit_v)
        fprintf('   %-12s: %.0f - %.0f m/s (%d/%d nokta)\n', ...
            gurultu_adi{ni}, tespit_v(1), tespit_v(end), kapsam(ni), n_hiz);
    else
        fprintf('   %-12s: HİÇBİR HIZDA TESPİT YOK\n', gurultu_adi{ni});
    end
end
min_kapsam = min(kapsam);
en_dar_idx = find(kapsam == min_kapsam);
if length(en_dar_idx) > 1
    isimler = strjoin(gurultu_adi(en_dar_idx), ', ');
    fprintf('   → En dar kapsam: %s (%d/%d, berabere)\n', isimler, min_kapsam, n_hiz);
else
    fprintf('   → En dar kapsam: %s (%d/%d)\n', gurultu_adi{en_dar_idx}, min_kapsam, n_hiz);
end
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  Kaydedilen şekiller (300 dpi):\n');
fprintf('  1) Sekil_01_Otokorelasyon.png\n');
fprintf('  2) Sekil_02_Pfa_Sapma.png\n');
fprintf('  3) Sekil_03_Pd_SNR.png\n');
fprintf('  3b)Sekil_03b_Pfa_Kontrol.png\n');
fprintf('  4) Sekil_04_Pd_JSR.png\n');
fprintf('  5) Sekil_05_Pd_Hiz.png\n');
fprintf('  6) Sekil_06_CFAR_Karsilastirma.png\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
%% ═══════════════════════════════════════════════════════════════
%  YARDIMCI FONKSİYONLAR
%  ═══════════════════════════════════════════════════════════════
function cikis = mti_filtre_matris(veri_2d, koef)
    [N_m, N_d] = size(veri_2d);
    derece = length(koef);
    if N_d < derece
        error('mti_filtre_matris: N_darbe (%d) < filtre derecesi (%d)', N_d, derece);
    end
    cikis_uzunluk = N_d - derece + 1;
    cikis = complex(zeros(N_m, cikis_uzunluk));
    for k = 1:derece
        cikis = cikis + koef(k) * veri_2d(:, k:(k + cikis_uzunluk - 1));
    end
end
function ref = cfar_ref_hesapla(guc_profil, hucre_idx, n_ref, n_koruma, cfar_tipi)
    guc_profil = guc_profil(:);  
    sol_bas = hucre_idx - n_koruma - n_ref;
    sol_bit = hucre_idx - n_koruma - 1;
    sag_bas = hucre_idx + n_koruma + 1;
    sag_bit = hucre_idx + n_koruma + n_ref;
    if sol_bas < 1 || sag_bit > length(guc_profil)
        ref = inf;
        return;
    end
    sol_ref = guc_profil(sol_bas:sol_bit);
    sag_ref = guc_profil(sag_bas:sag_bit);
    switch cfar_tipi
        case 1  
            ref = mean([sol_ref; sag_ref]);
        case 2  
            ref = max(mean(sol_ref), mean(sag_ref));
        case 3  
            ref = min(mean(sol_ref), mean(sag_ref));
        case 4  
            tum_ref = sort([sol_ref; sag_ref]);
            k = round(0.75 * length(tum_ref));
            ref = tum_ref(min(k, length(tum_ref)));
        otherwise
            ref = mean([sol_ref; sag_ref]);
    end
end