%% Post-MTI Hücre Güç Varyansı Analizi
% Bu betik:
%   - Şekil 8: Post-MTI hücre güç homojenliği analizi
%   - Şekil 9: Normalize post-MTI menzil güç profilleri
% üretir.
%
% Not:
%   generate_colored_noise.m aynı klasörde olmalıdır.

clear; clc; close all;
rng(42, 'twister');

%% Parametreler
fc        = 10e9;
lam       = 3e-2;
PRF       = 5000;
N_darbe   = 32;
N_menzil  = 60;
mti_koef  = [1, -2, 1];

N_mc      = 500;      % Monte Carlo koşum sayısı
SNR_dB    = 15;       % sabit SNR
JSR_dB    = 10;       % sabit JSR
out_dpi   = 300;

SNR_lin   = 10^(SNR_dB/10);
JSR_lin   = 10^(JSR_dB/10);
jam_guc   = JSR_lin * SNR_lin;   % birim gürültü gücü varsayımı altında

alpha_list = [0, 1, 2, -1];
isim_list  = {'Beyaz (\alpha=0)', 'Pembe (\alpha=1)', ...
              'Kahverengi (\alpha=2)', 'Mavi (\alpha=-1)'};
isim_kisa  = {'Beyaz', 'Pembe', 'Kahverengi', 'Mavi'};

renkler = [0.13 0.55 0.13;   % Beyaz -> yeşil
           0.90 0.40 0.60;   % Pembe
           0.55 0.27 0.07;   % Kahverengi
           0.16 0.39 0.82];  % Mavi

n_alpha = numel(alpha_list);

%% Veri toplama
% tum_guc(r, mc, ai): ai'inci gürültü tipi için
% mc'inci koşumdaki r'inci menzil hücresinin post-MTI entegre gücü
tum_guc = zeros(N_menzil, N_mc, n_alpha);

for ai = 1:n_alpha
    alpha = alpha_list(ai);

    for mc = 1:N_mc
        veri = zeros(N_menzil, N_darbe);

        for r = 1:N_menzil
            jammer = generate_colored_noise(N_darbe, alpha) * sqrt(jam_guc);
            awgn   = (randn(1, N_darbe) + 1j*randn(1, N_darbe)) / sqrt(2);
            veri(r, :) = jammer(:).' + awgn;
        end

        % Hedef YOK — yalnız jammer + termal gürültü

        % MTI uygula
        M = numel(mti_koef);
        cikis_uzunluk = N_darbe - M + 1;
        mti_cikis = zeros(N_menzil, cikis_uzunluk);

        for k = 1:M
            mti_cikis = mti_cikis + mti_koef(k) * veri(:, k:(k + cikis_uzunluk - 1));
        end

        % Noncoherent entegrasyon
        guc = mean(abs(mti_cikis).^2, 2);   % N_menzil x 1
        tum_guc(:, mc, ai) = guc;
    end

    fprintf('  %s tamamlandı (%d/%d)\n', isim_kisa{ai}, ai, n_alpha);
end

%% İstatistik hesapla
fprintf('\n%-15s %10s %10s %10s %10s %10s\n', ...
    'Gürültü', 'Ortalama', 'Std', 'CV', 'IQR', 'Var Oranı');
fprintf('%s\n', repmat('-', 1, 74));

beyaz_guc_tum = tum_guc(:, :, 1);
beyaz_var = var(beyaz_guc_tum(:));

stats = struct();
for ai = 1:n_alpha
    guc_tum = tum_guc(:, :, ai);
    guc_vec = guc_tum(:);

    ort      = mean(guc_vec);
    std_val  = std(guc_vec);
    cv_val   = std_val / ort;
    iqr_val  = iqr(guc_vec);
    var_oran = var(guc_vec) / beyaz_var;

    stats(ai).isim     = isim_kisa{ai};
    stats(ai).ort      = ort;
    stats(ai).std      = std_val;
    stats(ai).cv       = cv_val;
    stats(ai).iqr      = iqr_val;
    stats(ai).var_oran = var_oran;

    fprintf('%-15s %10.3f %10.3f %10.3f %10.3f %10.3f\n', ...
        isim_kisa{ai}, ort, std_val, cv_val, iqr_val, var_oran);
end

%% Her koşum için hücreler arası CV
cv_per_run = zeros(N_mc, n_alpha);
for ai = 1:n_alpha
    for mc = 1:N_mc
        guc_vec = tum_guc(:, mc, ai);
        cv_per_run(mc, ai) = std(guc_vec) / mean(guc_vec);
    end
end

%% ─────────────────────────────────────────────────────────────
% ŞEKİL 8: Post-MTI Hücre Güç Homojenliği Analizi
%% ─────────────────────────────────────────────────────────────
fig8 = figure('Position', [100 100 980 460], 'Color', 'w');
tl8 = tiledlayout(fig8, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

fs_axis  = 14;
fs_tick  = 18;
fs_title = 13;
grid_col = [0.85 0.85 0.85];

% Sol panel: tek koşumda hücre güç dağılımı
ornek_mc = 1;
guc_ornek = squeeze(tum_guc(:, ornek_mc, :));   % 60 x 4

ax1 = nexttile(tl8, 1);
boxplot(ax1, guc_ornek, 'Labels', isim_kisa, 'Whisker', 1.5, 'Symbol', 'k+');
renklendir_boxplot(ax1, renkler);

ylabel(ax1, 'Post-MTI entegre güç', 'FontWeight', 'bold', 'FontSize', fs_axis);
title(ax1, '(a) Tek koşumda hücre güç dağılımı', ...
    'FontWeight', 'bold', 'FontSize', fs_title);

grid(ax1, 'on');
box(ax1, 'on');
ax1.FontSize = fs_tick;
ax1.LineWidth = 1.0;
ax1.GridColor = grid_col;
ax1.GridAlpha = 0.9;
ax1.Layer = 'top';

% Sağ panel: tüm koşumlar için hücreler arası CV dağılımı
ax2 = nexttile(tl8, 2);
boxplot(ax2, cv_per_run, 'Labels', isim_kisa, 'Whisker', 1.5, 'Symbol', 'k+');
renklendir_boxplot(ax2, renkler);

ylabel(ax2, 'Hücreler arası CV', 'FontWeight', 'bold', 'FontSize', fs_axis);
title(ax2, sprintf('(b) %d koşum için CV dağılımı', N_mc), ...
    'FontWeight', 'bold', 'FontSize', fs_title);

grid(ax2, 'on');
box(ax2, 'on');
ax2.FontSize = fs_tick;
ax2.LineWidth = 1.0;
ax2.GridColor = grid_col;
ax2.GridAlpha = 0.9;
ax2.Layer = 'top';

sgtitle(tl8, 'Şekil 8. Post-MTI hücre güç homojenliği analizi', ...
    'FontWeight', 'bold', 'FontSize', 14);

exportgraphics(fig8, 'Sekil_08_Varyans_Boxplot.pdf', 'ContentType', 'vector');
exportgraphics(fig8, 'Sekil_08_Varyans_Boxplot.png', 'Resolution', out_dpi);
fprintf('\n✓ Figür kaydedildi: Sekil_08_Varyans_Boxplot\n');
%% ─────────────────────────────────────────────────────────────
% ŞEKİL 9: Normalize Post-MTI Menzil Güç Profilleri (Referans Görsel Boyutunda)
%% ─────────────────────────────────────────────────────────────
ornek_profiller = squeeze(tum_guc(:, ornek_mc, :));   % 60 x 4
prof_norm = zeros(size(ornek_profiller));
for ai = 1:n_alpha
    prof_norm(:, ai) = ornek_profiller(:, ai) / mean(ornek_profiller(:, ai));
end
yl = [0.95 * min(prof_norm(:)), 1.05 * max(prof_norm(:))];

% Boyutlar verdiğiniz yeni değere göre güncellendi (900x560)
fig9 = figure('Position', [60 60 900 560], 'Color', 'w');

% Font ailesini görseldeki gibi Times New Roman yapıyoruz
set(fig9, 'defaultAxesFontName', 'Times New Roman');
set(fig9, 'defaultTextFontName', 'Times New Roman');

tl9 = tiledlayout(fig9, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
alt_basliklar = {'(a) Beyaz', '(b) Pembe', '(c) Kahverengi', '(d) Mavi'};

for ai = 1:n_alpha
    ax = nexttile(tl9, ai);
    
    % Çizgi kalınlıkları referans görseldeki gibi dolgun (2.0)
    plot(ax, 1:N_menzil, prof_norm(:, ai), ...
        'Color', renkler(ai, :), 'LineWidth', 2.0);
    hold(ax, 'on');
    
    % Referans çizgisi 
    yline(ax, 1, '--k', 'LineWidth', 1.5);
    
    % Alt başlık puntoları (20 pt)
    title(ax, alt_basliklar{ai}, 'FontSize', 20, 'FontWeight', 'normal');
    
    xlim(ax, [1 N_menzil]);
    ylim(ax, yl);
    
    % Grid (Izgara) ayarları
    grid(ax, 'on');
    box(ax, 'on');
    ax.GridLineStyle = ':';
    ax.GridAlpha = 0.6;
    
    % Eksen numaraları (18 pt)
    ax.FontSize = 18;
    ax.LineWidth = 1.0;
    ax.Layer = 'top';
    
    % Sağ sütundaki grafiklerin (2 ve 4) Y ekseni numaralarını gizle
    if ismember(ai, [2 4])
        yticklabels(ax, []);
    end
    
    % Üst satırdaki grafiklerin (1 ve 2) X ekseni numaralarını gizle
    if ismember(ai, [1 2])
        xticklabels(ax, []);
    end
end

% Ortak X ve Y eksen isimleri (24 pt)
xlabel(tl9, 'Menzil hücresi', 'FontSize', 24, 'FontName', 'Times New Roman');
ylabel(tl9, 'Normalize güç', 'FontSize', 24, 'FontName', 'Times New Roman');

exportgraphics(fig9, 'Sekil_09_Menzil_Profil_ABCD.pdf', 'ContentType', 'vector');
exportgraphics(fig9, 'Sekil_09_Menzil_Profil_ABCD.png', 'Resolution', out_dpi); 
fprintf('✓ Figür kaydedildi: Sekil_09_Menzil_Profil_ABCD\n');

%% ─────────────────────────────────────────────────────────────
% Yardımcı fonksiyon: boxplot renklendirme
%% ─────────────────────────────────────────────────────────────
function renklendir_boxplot(ax, renkler)
    % Box objeleri soldan sağa gelsin diye ters çeviriyoruz
    box_handles    = flipud(findobj(ax, 'Tag', 'Box'));
    median_handles = flipud(findobj(ax, 'Tag', 'Median'));
    whisk_handles  = flipud(findobj(ax, 'Tag', 'Whisker'));
    adj_handles    = flipud(findobj(ax, 'Tag', 'Adjacent Value'));
    out_handles    = findobj(ax, 'Tag', 'Outliers');

    n = min(numel(box_handles), size(renkler, 1));

    for i = 1:n
        set(box_handles(i), 'Color', renkler(i, :), 'LineWidth', 1.5);

        if i <= numel(median_handles)
            set(median_handles(i), 'Color', 0.55 * renkler(i, :), 'LineWidth', 1.7);
        end
    end

    % Her grup için 2 whisker ve 2 adjacent value var
    for i = 1:min(floor(numel(whisk_handles)/2), n)
        idx = 2*i - 1;
        set(whisk_handles(idx:idx+1), 'Color', renkler(i, :), 'LineWidth', 1.2);
    end

    for i = 1:min(floor(numel(adj_handles)/2), n)
        idx = 2*i - 1;
        set(adj_handles(idx:idx+1), 'Color', renkler(i, :), 'LineWidth', 1.2);
    end

    for i = 1:numel(out_handles)
        set(out_handles(i), 'MarkerEdgeColor', [0.25 0.25 0.25]);
    end
end