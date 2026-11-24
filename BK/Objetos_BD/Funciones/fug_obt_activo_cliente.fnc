create or replace function it.fug_obt_activo_cliente(p_in_cod_persona in ba_personas.cod_persona%type)
  return number is

  v_activo     ge_cuentas.sal_promedio%type := 0;
  v_pasivo     ge_cuentas.sal_promedio%type := 0;
  v_saldo_gs   ge_cuentas.sal_promedio%type;
  v_cotizacion GE_COTIZACIONES.VAL_CONVERSION%TYPE;

  CURSOR cuentas is
  
    select cc.nro_cuenta,
           cc.cod_persona,
           cc.cod_oficina,
           cc.cod_modulo,
           cc.cod_modalidad,
           cc.relacion,
           mo.descripcion des_modulo,
           InitCap(ma.descripcion) des_modalidad,
           c.estado,
           c.sal_contable,
           c.cod_moneda,
           c.fec_apertura,
           c.fec_cam_estado,
           c.cod_tasa,
           c.fec_insercion,
           c.tas_personalizada,
           es.descripcion des_estado,
           c.dia_atraso,
           c.max_atraso,
           c.pro_atraso,
           c.mto_mora,
           c.sal_promedio,
           c.en_juicio,
           c.fec_juicio,
           c.cod_ent_juicio,
           fug_obt_contingencia(c.nro_cuenta) contingencia,
           cl.cat_riesgo,
           cl.cat_sistema,
           cl.fec_ult_clasif,
           cl.tot_deu_sistema
      from ge_est_cuentas  es,
           ba_modulos      mo,
           ge_modalidades  ma,
           ge_cuentas      c,
           ge_cta_clientes cc,
           ge_clientes     cl
     where es.cod_modulo(+) = c.cod_modulo
       and es.cod_modalidad(+) = c.cod_modalidad
       and es.estado(+) = c.estado
          --  and es.estado = 'N'
       and ma.cod_modalidad = cc.cod_modalidad
       and ma.cod_modulo = cc.cod_modulo
       and mo.cod_modulo = cc.cod_modulo
       and c.cod_modulo = cc.cod_modulo
       and c.cod_modalidad = cc.cod_modalidad
       and c.nro_cuenta = cc.nro_cuenta
       and cc.cod_persona = cl.cod_persona
       and cc.cod_persona = p_in_cod_persona;

begin
  FOR cta IN cuentas LOOP
  
    v_saldo_gs := 0;
  
    IF 'GS' = cta.cod_moneda THEN
      v_saldo_gs := cta.sal_contable;
    
    ELSE
      v_cotizacion := pag_gen.fu_obt_cotizacion(cta.cod_moneda, sysdate);
      v_saldo_gs   := cta.sal_contable * nvl(v_cotizacion, 0);
    
    END IF;
  
    IF cta.cod_modulo = 5 then
    
      v_activo := v_activo + v_saldo_gs;
    
    ELSIF cta.cod_modulo = 6 then
    
      v_activo := v_activo + v_saldo_gs;
    
    ELSIF cta.cod_modulo = 8 then
    
      v_activo := v_activo + v_saldo_gs;
    
    ELSIF cta.cod_modulo = 3 THEN
    
      v_pasivo := v_pasivo + v_saldo_gs;
    
    ELSIF cta.cod_modulo = 4 THEN
    
      IF v_saldo_gs < 0 THEN
      
        v_activo := v_activo + (v_saldo_gs * -1);
      
      ELSE
      
        v_pasivo := v_pasivo + v_saldo_gs;
      
      END IF;
    
    END IF;
  
  END LOOP;

  return v_activo;

end fug_obt_activo_cliente;
/

