create or replace procedure it.PRM_GEN_CTA_DOCUMENTO
is
  r_gcli          ge_cta_clientes%rowtype;
  r_gmovi         ge_movimientos%rowtype;
  --
  r_mcta          md_cta_documentos%rowtype;
  v_nro_cta_padre md_cta_documentos.nro_cta_padre%type;
  v_fec_inicio    md_cta_documentos.fec_inicio%type;
  v_sum_interes   md_cta_documentos.mto_interes%type := 0;
  --
  v_cod_oficina   ge_movimientos.cod_oficina%type;
  v_fec_actual    ge_movimientos.fecha%type := pae_cnf.fu_obt_fec_actual(10);
  v_hora          ge_movimientos.hora%type  := to_char(sysdate,'hh24:mi:ss');
  v_nro_secuencia ge_movimientos.nro_secuencia%type := 0;
  v_cotizacion    ge_movimientos.cotizacion%type;
  --
  v_moneda        varchar2(1);
  v_duplica       varchar2(1);
  v_can_cupon     number;
  v_dia_interes   number;
  v_redondeo      number;
  v_diferencia    number;
  v_cod_persona   varchar2(20);
  --v_max_valor     number;
  v_inserta       varchar2(1);
  v_mensaje       varchar2(200);
  -- Cursor de Tabla temporal con datos del Excel.
  cursor cta is
    select upper(moneda) moneda, tasa, monto,
           titulo, cupon, fec_compra,
           fec_vencimiento, upper(denominacion) denominacion,
           cod_modalidad, cod_persona
      from md_cta_doc_tmp
     order by titulo, cupon;
  -- Proceso de Inserción de la cuenta.
  procedure lp_ins_cta_documento is
  begin
    insert into md_cta_documentos
                ( cod_modulo, nro_cuenta, cod_modalidad,
                  cod_oficina, cod_moneda, cod_persona,
                  nro_documento, denominacion, fec_inicio,
                  fec_vencimiento, monto, val_tasa, cantidad,
                  estado, fec_cam_estado, mto_interes,
                  val_presente, sal_interes, beneficiario,
                  tip_calculo, nro_cta_padre, com_doc_relacionados,
                  sal_val_presente, cod_instruccion, for_pago,
                  nro_ref_credito, dia_ano, cod_ofi_credito,observacion,
                  mer_secundario)
            values
                ( r_mcta.cod_modulo, r_mcta.nro_cuenta, r_mcta.cod_modalidad,
                  r_mcta.cod_oficina, r_mcta.cod_moneda, r_mcta.cod_persona,
                  r_mcta.nro_documento, r_mcta.denominacion, r_mcta.fec_inicio,
                  r_mcta.fec_vencimiento, r_mcta.monto, r_mcta.val_tasa,
                  r_mcta.cantidad, r_mcta.estado, r_mcta.fec_cam_estado,
                  r_mcta.mto_interes, r_mcta.val_presente, r_mcta.sal_interes,
                  r_mcta.beneficiario, r_mcta.tip_calculo, r_mcta.nro_cta_padre,
                  r_mcta.com_doc_relacionados, r_mcta.sal_val_presente, r_mcta.cod_instruccion,
                  r_mcta.for_pago, r_mcta.nro_ref_credito, r_mcta.dia_ano, r_mcta.cod_ofi_credito,'PROCESO AUTOMATICO - CARGA DOCUMENTO.', 
                  r_mcta.mer_secundario);
    --
    insert into ge_cta_clientes
             ( cod_persona, nro_cuenta, dig_verificador, 
               cod_oficina, cod_modulo, cod_modalidad,relacion)
       values( r_gcli.cod_persona, r_gcli.nro_cuenta, r_gcli.dig_verificador, 
               r_gcli.cod_oficina, r_gcli.cod_modulo, r_gcli.cod_modalidad, 
               r_gcli.relacion);
  end;
  
begin
  -- Busca Beneficiario
  begin
    select nom_entidad
      into r_mcta.beneficiario
      from ge_par_generales;
  exception
    when others then
      raise_application_error(-20000,'Error al Buscar El Beneficiario. '||sqlerrm );
  end;
  -- Oficina del Usuario
  v_cod_oficina := fug_obt_ofi_usuario(user);
  --
  r_mcta.cod_oficina     := 31;
  r_mcta.cod_modulo      := 10;

  r_mcta.dia_ano         := 365;
  r_mcta.estado          := 'S';
  r_mcta.tip_calculo     := 'A';
  r_mcta.cod_instruccion := 'C';
  r_mcta.for_pago        := 'R';
  r_mcta.cod_ofi_credito := r_mcta.cod_oficina;
  v_cod_persona          := fug_obt_pardinamico('MD_COD_PERSONA',r_mcta.cod_modulo,r_mcta.cod_modalidad,null,null);
  -- Datos de Cta. Clientes

  r_gcli.dig_verificador := 0;
  r_gcli.cod_oficina     := r_mcta.cod_oficina;
  r_gcli.cod_modulo      := r_mcta.cod_modulo;
  r_gcli.relacion        := 'P';
  -- Cursor de Documentos.
  for c in cta loop
    -- Verifica la Moneda
    begin
      select distinct 'S'
        into v_moneda
        from ba_monedas
       where cod_moneda = c.moneda;
    exception
      when others then
        raise_application_error(-20000,'Error al Buscar la Moneda "'||c.moneda||'" del Título '||c.titulo||' Cupón '||c.cupon||'. '||sqlerrm );
    end;
    --
    r_mcta.nro_ref_credito := fug_obt_pardinamico('MD_COD_RUBRO',r_mcta.cod_modulo,r_mcta.cod_modalidad,c.moneda,null);
    --
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_mcta.cod_modulo,r_mcta.cod_modalidad,c.moneda);
    --
    r_mcta.cod_modalidad   := nvl(c.cod_modalidad,105);   
    r_gcli.cod_persona     := nvl(c.cod_persona,v_cod_persona); 
    r_mcta.cod_persona     := r_gcli.cod_persona;  
    r_gcli.cod_modalidad   := r_mcta.cod_modalidad; 
    --    
    r_mcta.nro_cuenta := fug_obt_sig_nro_cuenta(r_mcta.cod_modulo, r_mcta.cod_modalidad, r_mcta.cod_oficina, r_mcta.cod_moneda, r_mcta.cod_persona);
 
    --     
    if c.cupon in (0,1) then
      r_mcta.fec_inicio := c.fec_compra;
    else
      -- Si la cuota es diferente a 0 o 1, la Fecha de Inicio es la fecha de Vencimiento anterior mas 1 día.
      r_mcta.fec_inicio := r_mcta.fec_inicio + 1;
    end if;
    -- Cupon 0 es el principal.
    if c.cupon = 0 then
      -- Carga la variable que permite insertar el registro.
      v_inserta := 'S';
      -- Control que no permita ingresar varias veces de forma automática el mismo documento.
      begin
        select distinct 'S'
          into v_duplica
          from md_cta_documentos
         where nro_documento like 'Tít '||c.titulo||'%'
           and observacion = 'PROCESO AUTOMATICO - CARGA DOCUMENTO.';
      exception
        when no_data_found then
          v_duplica := 'N';
      end;
      --
      if nvl(v_duplica,'N') = 'S' then
        v_inserta := 'N';
        v_mensaje := 'Documento ya fue ingresado. Título '||c.titulo;
      end if;
      --
      v_sum_interes               := 0;
      v_fec_inicio                := r_mcta.fec_inicio;
      r_mcta.cantidad             := 0;
      r_mcta.nro_cta_padre        := null;
      v_nro_cta_padre             := r_mcta.nro_cuenta;
      r_mcta.com_doc_relacionados := 'N';
      r_mcta.mer_secundario       := 'N';
      r_mcta.val_tasa             := c.tasa/* 100*/;
      -- Los días de interés es por el Plazo Total.
      v_dia_interes               := c.fec_vencimiento - c.fec_compra;
      r_mcta.mto_interes          := c.monto - Round(c.monto / (1+(r_mcta.val_tasa * nvl(v_dia_interes,0)/(r_mcta.dia_ano*100))),v_redondeo);
      --
      begin
        -- Carga la Cantidad de Cupones 
        -- y la Sumatoria de Los Valores Actuales de los Cupones, esto debe ser igual al Interés del Capital.
        select count(1), 
               sum(monto - (monto - Round(monto / (1+(r_mcta.val_tasa * nvl(v_dia_interes,0)/(r_mcta.dia_ano*100))),v_redondeo) ) )
          into v_can_cupon, v_sum_interes
          from md_cta_doc_tmp
         where titulo = c.titulo
           and cupon <> 0;
      exception
        when others then
          raise_application_error(-20000,'Error al buscar cantidad de Cupones, Título '||c.titulo||' Cupón '||c.cupon||', '||sqlerrm);
      end;
      --
      --No debe verificar los montos ya que todos los documentos deben ingresar.
      v_diferencia := r_mcta.mto_interes - v_sum_interes;
      --
      --if v_redondeo = 0 then
      --  v_max_valor := 100;
      --else
      --  v_max_valor := 10;
      --end if;
      --if abs(v_diferencia) > v_max_valor then
      --  v_inserta := 'N';
      --  v_mensaje := 'Error en el cálculo de cupones. Verificar consistencia de Montos. Diferencia = '||abs(v_diferencia);
      --end if;
      
      if v_inserta = 'N'  then
        -- Si hay error inserta en el Log.
        insert into log_md_cta_documentos
          (titulo, cupon, mto_interes, sum_interes, mensaje)
        values
          (c.titulo, c.cupon, r_mcta.mto_interes, v_sum_interes, v_mensaje);
      end if;
    else
      r_mcta.cantidad             := 1;
      r_mcta.nro_cta_padre        := v_nro_cta_padre;
      r_mcta.com_doc_relacionados := 'S';
      r_mcta.mer_secundario       := null;
    end if;
    --
    if v_inserta = 'S' then
      r_mcta.cod_moneda       := c.moneda;
      r_mcta.nro_documento    := 'Tít '||c.titulo||' Nº '||c.cupon;
      r_mcta.denominacion     := c.denominacion;
      r_mcta.fec_vencimiento  := c.fec_vencimiento;
      r_mcta.monto            := c.monto;
      r_mcta.mto_interes      := c.monto - Round(c.monto / (1+(r_mcta.val_tasa * nvl(v_dia_interes,0)/(r_mcta.dia_ano*100))),v_redondeo);
      --
      if c.cupon = 0 and abs(v_diferencia) > 0 then
        -- Actualiza el Interés del Capital.
        r_mcta.mto_interes  := r_mcta.mto_interes - v_diferencia;
      end if;
      --      
      r_mcta.val_presente     := c.monto - nvl(r_mcta.mto_interes,0);
      r_mcta.sal_interes      := r_mcta.mto_interes;
      r_mcta.sal_val_presente := r_mcta.val_presente; 
      -- Datos de Cta. Clientes
      r_gcli.nro_cuenta       := r_mcta.nro_cuenta;
      -- Inserta las Cuentas.
      begin
        lp_ins_cta_documento;
      exception
        when others then
          raise_application_error(-20000,'Error al Insertar el Bono, Título '||c.titulo||' Cupón '||c.cupon||' Cta '||r_mcta.nro_cuenta||', '||sqlerrm);
      end;
      -- Guarda la Fecha de Vencimiento para calcular la fecha de Inicio del siguiente cupón.    
      r_mcta.fec_inicio := r_mcta.fec_vencimiento;
      --
      --*** Desembolso del Documento ***--
      if v_nro_secuencia = 996 then
        v_nro_secuencia := 0;
        v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end if;
      --
      v_nro_secuencia := v_nro_secuencia + 1;
      --
      pam_doc.pr_com_documentos(r_mcta.nro_cuenta,
                               r_mcta.val_presente,
                               v_cod_oficina,
                               0,
                               v_fec_actual,
                               v_hora,
                               v_nro_secuencia);	
      --
      if c.cupon = 0 then
        --
        if v_nro_secuencia = 999 then
          v_nro_secuencia := 0;
          v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
        end if;
        v_nro_secuencia := v_nro_secuencia + 1;
        --
        if r_mcta.cod_moneda <> pag_gen.fu_obt_mon_local then
          v_cotizacion := fug_obt_cotizacion(r_mcta.cod_moneda,v_fec_actual);
        end if;
        --
        -- Movimiento por el Rubro Contable.
        r_gmovi.cod_usuario := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        --
        r_gmovi.cod_modulo      := r_mcta.cod_modulo;
        r_gmovi.cod_modalidad   := r_mcta.cod_modalidad;
        r_gmovi.cod_oficina     := r_mcta.cod_ofi_credito;
        r_gmovi.cod_moneda      := r_mcta.cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.cod_tra_padre   := 101;
        r_gmovi.cod_mod_padre   := r_mcta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_mcta.cod_modalidad;
        r_gmovi.cod_transaccion := 741;
        r_gmovi.monto           := r_mcta.monto;
        r_gmovi.nro_documento   := r_mcta.nro_cuenta;
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Compra Documento ' ||r_mcta.nro_cuenta;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_rubro       := r_mcta.nro_ref_credito;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.tip_mov_rubro   := 'C';
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion);
        --
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
        --
      end if;
    end if;    
  end loop;
end;
/

