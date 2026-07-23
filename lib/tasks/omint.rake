# frozen_string_literal: true

namespace :omint do
  desc "Probe Omint's live API (token + CreateQuotationB2B): bin/rails omint:probe"
  task probe: :environment do
    # Al 22/07/2026 el ambiente de test de Omint responde 500 con cuerpo vacío
    # a *cualquier* payload — la causa está en el header `www-authenticate`
    # (OpenIddict ID2170: su API no puede validar el token contra su propio
    # authorization server). Esta tarea existe para volver a chequear en un
    # comando si ya lo arreglaron, sin tener que armar un script cada vez.
    #
    # Usa métodos privados del provider a propósito: sondea cada etapa por
    # separado (token / POST crudo / normalización) para saber *dónde* falla.
    # `abort` escribe a stderr: sin esto el mensaje de error aparece antes que
    # el progreso cuando se redirige la salida.
    $stdout.sync = true

    provider = Provider.find_by(slug: "omint")
    abort "No hay Provider con slug 'omint'. Corré bin/rails db:seed." if provider.nil?

    client = InsuranceProviders::OmintProvider.new(provider)

    puts "Proveedor: #{provider.name} (status: #{provider.status})"
    puts "base_url:  #{provider.config_for(:base_url)}"
    puts

    # 1. Token — siempre pide uno nuevo: un token cacheado esconde justamente
    #    el fallo de autenticación que queremos detectar.
    Rails.cache.delete(client.send(:token_cache_key))
    token = begin
      client.send(:access_token)
    rescue StandardError => e
      abort "✗ TOKEN: #{e.class}: #{e.message}"
    end
    puts "✓ TOKEN: obtenido (#{token.to_s.length} chars)"

    # 2. POST crudo — pasa por #build_payload para ejercitar también nuestro
    #    mapeo de origen/destino/fechas, no sólo la conectividad.
    sample = Struct.new(:trip_type, :origin, :destination, :departure_date, :return_date, :ages, :traveler)
      .new("single", "Argentina", "Brasil", Date.current + 15, Date.current + 25, [ 30 ], nil)

    payload = client.send(:build_payload, sample)
    puts "\nPayload de prueba:"
    puts JSON.pretty_generate(payload).lines.map { |l| "  #{l}" }.join

    response = begin
      client.send(:post_quotation, payload)
    rescue Faraday::Error => e
      # El host de test se cae seguido y tira ENETUNREACH/timeout: sin este
      # rescue la tarea escupe un backtrace de 30 líneas que no dice nada.
      abort "✗ CONEXIÓN: no se pudo llegar a #{provider.config_for(:base_url)} — #{e.class}: #{e.message[0, 200]}"
    end
    puts "\nHTTP #{response.status}"

    if response.success?
      results = client.quote(sample)
      puts "✓ COTIZACIÓN OK — #{results.size} producto(s):"
      results.each { |r| puts "    #{r[:plan_name]}: #{r[:price_cents].to_i / 100.0} #{r[:currency]}" }
      puts "\nOmint está respondiendo. Se puede retomar la tarea 6.1 de integrate-omint-provider."
    else
      body = response.body.presence || "(cuerpo vacío)"
      puts "✗ COTIZACIÓN FALLÓ"
      puts "  body: #{body.to_s[0, 500]}"

      # El motivo real del 500 viene acá, no en el body.
      if (challenge = response.headers["www-authenticate"])
        puts "  www-authenticate: #{challenge}"
      end
      abort "\nOmint sigue rota. Nada para arreglar de nuestro lado si el error es ID2170."
    end
  end
end
