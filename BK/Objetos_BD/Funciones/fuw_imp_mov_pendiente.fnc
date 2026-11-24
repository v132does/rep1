CREATE OR REPLACE FUNCTION IT.FUW_IMP_MOV_PENDIENTE
  (P_NRO_DOCUMENTO in BW_MOV_PENDIENTES.NRO_DOCUMENTO%TYPE,
   p_imp_comentario in varchar2,
   p_estado in varchar2 default 'P')
  return clob is
  
  --devuelve los datos del movimiento pendiente de autorizar en formato html para imprimir en la web
  v_cod_per_principal bw_mov_pendientes.cod_per_principal%type;
  v_fec_hora          bw_mov_pendientes.fec_hora%type;
  v_cod_tip_mensaje   bw_mov_pendientes.cod_tip_mensaje%type;
  v_descripcion       bw_mov_pendientes.descripcion%type;
  v_monto             bw_mov_pendientes.monto%type;
  v_mto_cargo         bw_mov_pendientes.mto_cargo%type;
  v_mto_iva           bw_mov_pendientes.mto_iva%type;
  v_cotizacion        bw_mov_pendientes.cotizacion%type;
  v_equ_local         bw_mov_pendientes.mto_equ_local%type;
  v_cot_contra        bw_mov_pendientes.cot_contra%type;
  v_mto_contra        bw_mov_pendientes.mto_contra%type;
  v_estado            bw_mov_pendientes.estado%type;
  v_can_aut_requeridas bw_mov_pendientes.can_aut_requeridas%type;
  v_can_aut_faltantes  bw_mov_pendientes.can_aut_faltantes%type;
  v_etiqueta          bw_mov_pendientes.etiqueta%type;
  v_dato              bw_mov_pendientes.dato%type;
  v_etiqueta2         bw_mov_pendientes.etiqueta2%type;
  v_dato2             bw_mov_pendientes.dato2%type;  
  v_cod_per_ingreso   bw_mov_pendientes.cod_per_ingreso%type;
  v_cod_moneda        ge_movimientos.cod_moneda%type; 
  v_cta_formateada    varchar2(20);
  v_cta_contra_formateada    varchar2(20);
  v_error             varchar2(1000);
  v_nro_cuenta        ge_movimientos.nro_cuenta%type;
  v_cta_contra        ge_movimientos.nro_cuenta%type;
  v_cantidad          number;
  v_existe            varchar2(1);
  v_des_tip_mensaje   bw_tip_mensajes.descripcion%type;
  v_nro_tarjeta       ta_tarjetas.nro_tarjeta%type;
  v_nro_tar_contra    ta_tarjetas.nro_tarjeta%type;
  v_cod_mod_contra    ge_cuentas.cod_modulo%type; 
  v_cod_mad_contra    ge_cuentas.cod_modalidad%type;
  v_cod_ofi_contra    ge_cuentas.cod_oficina%type;
  v_cod_mon_contra    ge_cuentas.cod_moneda%type;
  v_denominacion      ge_cuentas.denominacion%type;
  v_tip_pro_sueldo    varchar2(1):=NULL; --BBVADES-2376
    
  -- OMM 09/12/2010 Para tener pendiente mas de 1 pago a autorizar AP 1095
  v_referencia        bw_mov_pendientes.referencia%type;
  -- movimientos pendientes de sueldos
  cursor c_sue_pendientes(p_cod_ente in number, p_nro_archivo in number) is
     select x.nro_cuenta, substr(z.denominacion,1,40) denominacion, nvl(x.cod_moneda,v_cod_moneda) cod_moneda, x.monto  
       from ge_cuentas z,ge_pag_sueldos_tmp x
      where x.cod_ente = p_cod_ente 
        and x.fec_envio = paw_bce.v_fec_actual
        and x.estado = 'H'
        and x.tipo = 'C'
        and nvl(x.nro_archivo,0) = nvl(p_nro_archivo,0)
        and to_char(x.nro_cuenta) = z.nro_cuenta;
  -- movimientos confirmados de sueldos
  cursor c_sue_confirmados(p_cod_ente in number, p_nro_archivo in number) is

     select x.nro_cuenta, substr(z.denominacion,1,40) denominacion, nvl(x.cod_moneda,v_cod_moneda) cod_moneda, x.monto  
       from ge_cuentas z,ge_pag_sueldos x
      where x.cod_ente = p_cod_ente 
        and x.fec_envio = paw_bce.v_fec_actual
        and x.estado = 'N'
        and x.tipo = 'C'
        and x.procesado = 'S'
        and nvl(x.nro_secuencia,0) = nvl(p_nro_archivo,0)
        and to_char(x.nro_cuenta) = z.nro_cuenta;
  -- movimientos pendientes de proveedores
  cursor pagos(p_cod_ente in number, p_nro_archivo in number) is
     select x.nro_orden, 
            decode(x.for_pago,'G','Cheque','Credito') for_pago,
            nvl(substr(z.denominacion,1,40),x.beneficiario) denominacion, 
            nvl(x.cod_moneda,v_cod_moneda) cod_moneda, x.monto  
       from ge_cuentas z,ge_pag_proveedores_tmp x
      where x.cod_ente = p_cod_ente 
        and x.fec_ingreso = trunc(sysdate)
        and x.tip_carga = 'H'
        and x.cod_usu_operador = user
        and x.nro_cta_credito = z.nro_cuenta(+)
        and nvl(x.nro_archivo, 0) = nvl(p_nro_archivo, 0);
  -- movimientos confirmados de proveedores
  cursor c_pro_pagados(p_cod_ente in ge_pag_proveedores.cod_ente%type, p_nro_archivo in number) is
     select x.nro_orden, 
            decode(x.for_pago,'G','Cheque','Credito') for_pago,
            nvl(substr(z.denominacion,1,40),x.beneficiario) denominacion, 
            nvl(x.cod_moneda,v_cod_moneda) cod_moneda, x.monto  
       from ge_cuentas z,ge_pag_proveedores x
      where x.cod_ente = p_cod_ente 
        and x.fec_ingreso = trunc(sysdate)
        and x.tip_carga = 'H'
        and x.cod_usu_operador = user
        and x.nro_cta_credito = z.nro_cuenta(+)
        and x.referencia = p_nro_documento
        and nvl(x.nro_archivo, 0) = nvl(p_nro_archivo, 0);
  --detalles de autorizaciones
  cursor detalles is
    select a.cod_persona, a.fec_hora, decode(a.accion,'A','Autorizado','Rechazado') accion, a.observacion,
           b.nom_completo nombre
      from ba_personas b, bw_autorizaciones a
     where a.nro_documento = p_nro_documento
       and a.cod_persona = b.cod_persona
     order by fec_hora;
 v_cont number:= 0; 
 v_retorno clob := '';   
begin
  --recupera el movimiento principal
  begin
    select cod_per_principal, fec_hora, a.cod_tip_mensaje, b.descripcion, nro_cuenta, cod_moneda, 
           a.descripcion, monto, nvl(mto_cargo,0), nvl(mto_iva,0), cotizacion, mto_equ_local, 
           cantidad, nro_cta_contra, estado, can_aut_requeridas, 
           can_aut_faltantes, etiqueta, dato, cod_per_ingreso,
           decode(a.nro_cuenta,null,null,fug_cta_formateada(null,null,null,a.nro_cuenta,a.cod_moneda)),
           decode(a.nro_cta_contra,null,null,fug_cta_formateada(null,null,null,a.nro_cta_contra,null)),
           a.cot_contra, a.mto_contra, a.etiqueta2, a.dato2,a.referencia
      into v_cod_per_principal, v_fec_hora, v_cod_tip_mensaje, v_des_tip_mensaje, v_nro_cuenta, v_cod_moneda, 
           v_descripcion, v_monto, v_mto_cargo, v_mto_iva, v_cotizacion, v_equ_local,
           v_cantidad, v_cta_contra, v_estado, v_can_aut_requeridas,
           v_can_aut_faltantes, v_etiqueta, v_dato, v_cod_per_ingreso,
           v_cta_formateada, v_cta_contra_formateada, v_cot_contra, v_mto_contra,
           v_etiqueta2, v_dato2, v_referencia
      from bw_tip_mensajes b, bw_mov_pendientes a
     where a.nro_documento = p_nro_documento
       and a.cod_tip_mensaje = b.cod_tip_mensaje;
  exception
     when no_data_found then
       v_error := 'No existe Movimiento Pendiente. Avise al Oficial.';
     when too_many_rows then
       v_error := 'Varios Movimientos con el mismo criterio. Avise al Oficial.';
     when others then
       v_error := 'No se puede recuperar Mov.Pendiente '||p_nro_documento || sqlerrm;
  end;
          
  if v_nro_cuenta is not null then --recuperar datos de la cuenta, pag_cta porque es 3 o 4
    pag_cta.PR_OBT_CUENTA(v_nro_cuenta);
     IF PAG_CTA.FU_OBT_COD_ERROR() <> 0 THEN
      v_error := 'Recup.Cta '||pag_cta.fu_obt_msj_error();
    END IF;
    if pag_cta.G_CTAS.cod_modulo = 5 then --tarjeta
       v_nro_tarjeta := fut_for_tarjeta(fut_obt_nro_tarjeta(v_nro_cuenta));
    else
       v_nro_tarjeta := null;
    end if;
  end if;
  --recuperar datos de la cuenta contrapartida, no usa pag_cta porque puede ser préstamo
  if v_cta_contra is not null then
    begin
      Select a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.cod_moneda, denominacion
        into v_cod_mod_contra, v_cod_mad_contra, v_cod_ofi_contra, v_cod_mon_contra, v_denominacion
        from ge_cuentas a
       where a.nro_cuenta = v_cta_contra;
    exception
       when others then
         v_error := 'Recup.Cta Contrap. '||sqlerrm;
    end;
  end if;
  
  --BBVADES-2376
  if v_cod_tip_mensaje='070' then
    v_tip_pro_sueldo:=nvl(fug_obt_parentes(v_dato,'TIP_PRO_SUELDO'),'O');
    if v_dato2 = 'A' then
       -- pagos de aguinaldo debe ser online sin importar
       -- la configuracion del ente
       v_tip_pro_sueldo := 'O';
    end if;
  end if;
  --Fin BBVADES-2376  
  if v_cod_tip_mensaje='036' then
     if substr(v_des_tip_mensaje,0,35)='TRANSFERENCIA INTERBANCARIA OTROS B' then
        v_des_tip_mensaje:='TRANSFERENCIA A OTROS BANCOS';
     END IF;
  end if;
  
  --arma html
  pag_htm.v_texto := '';-- inicializo el texto
  --pag_htm.PR_ENCABEZADO;
 -- pag_htm.PR_CUERPO('S'); -- ABRE EL CUERPO
--  
  --si hubo error devolver el msj de error, sino imprimir comprobante
  if v_error is not null then
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_COLUMNA(substr(v_error,1,600),NULL,'center','S'); -- agrego la columna etiqueta
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    
  else
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_COLUMNA(v_des_tip_mensaje,NULL,'center','S'); -- agrego la columna etiqueta
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal
    
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Nro. Operaci&oacute;n:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(p_nro_documento); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
  
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Fecha:',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(to_char(v_fec_hora,'dd/mm/yyyy - hh24:mi:ss')); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
 
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA

         pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
         pag_htm.PR_FILA('S'); -- ABRO LA FILA
         pag_htm.PR_COLUMNA('Cuenta:',120,'left','S'); -- agrego la columna etiqueta
         pag_htm.PR_COLUMNA(nvl(v_nro_tarjeta,v_cta_formateada) ||' - ' ||pag_cta.FU_OBT_NOM_CUENTA,310); -- agrego la columna del nro de cuenta
         pag_htm.PR_COLUMNA('Tipo:',10,'left','S');
         pag_htm.PR_COLUMNA(fue_obt_titulo(fug_obt_des_modal(pag_cta.G_CTAS.cod_modulo,pag_cta.g_ctas.cod_modalidad)),null,'left'); 
         pag_htm.PR_FILA('N'); -- CIERRO LA FILA
         pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA  
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
         pag_htm.PR_COLUMNA('Moneda:',120,'left','S'); -- agrego la columna etiqueta
         pag_htm.PR_COLUMNA(FUE_OBT_DES_MONEDA(v_cod_moneda),310); -- agrego la columna del nro de cuenta
         pag_htm.PR_COLUMNA('Oficina:',10,'left','S');
         pag_htm.PR_COLUMNA(fue_obt_titulo(fue_obt_des_oficina(pag_cta.G_CTAS.COD_OFICINA)),null,'left');
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA

    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal

    
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Monto: ',120,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_cod_moneda,30,'left');
      pag_htm.PR_COLUMNA(to_char(v_monto,'999,999,999,999.99'),120,'right');
      pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      if v_mto_cargo > 0 then
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Cargo: ',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_cod_moneda,30,'left');
        pag_htm.PR_COLUMNA(to_char(v_mto_cargo,'999,999,999,999.99'),120,'right');
        pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      end if;
      if v_mto_iva > 0 then
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('IVA: ',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_cod_moneda,30,'left');
        pag_htm.PR_COLUMNA(to_char(v_mto_iva,'999,999,999,999.99'),120,'right');
        pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA      
      end if;
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
         
    
    if v_cotizacion is not null and v_cotizacion <> 1 then
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Cotizaci&oacute;n: ',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(to_char(v_cotizacion,'999,999,999,999.99'),150,'right');
        pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA    
        
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Equivalente GS: ',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(to_char(v_equ_local,'999,999,999,999.99'),150,'right');
        pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA        
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    end if;      

    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      if v_cod_tip_mensaje = '036' then
         pag_htm.PR_COLUMNA('Descripci&oacute;n:',120,'left','S'); -- agrego la columna etiqueta
      else
         pag_htm.PR_COLUMNA('Concepto:',120,'left','S'); -- agrego la columna etiqueta
      end if;
      pag_htm.PR_COLUMNA(v_descripcion); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
 
    if v_cantidad > 0 then
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Cantidad:',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_cantidad,NULL,'left'); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    end if;

    if v_etiqueta is not null then
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        v_etiqueta := trim(pag_htm.FU_CON_HTML(v_etiqueta));
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA(v_etiqueta||':',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_dato,null,'left'); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    end if;      

    if v_etiqueta2 is not null then
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        v_etiqueta2 := trim(pag_htm.FU_CON_HTML(v_etiqueta2));
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA(v_etiqueta2||':',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA(v_dato2,null,'left'); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    end if;  
    
    if v_cta_contra is not null then
      if v_cod_mod_contra = 5 then --tarjeta
         v_nro_tar_contra := fut_for_tarjeta(fut_obt_nro_tarjeta(v_cta_contra));
      else
         v_nro_tar_contra := null;
      end if;
        pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA(null,null); -- agrego la columna del nro de cuenta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.pr_texto('<hr width=630>');
        if v_cod_mod_contra = 6 then
          pag_htm.PR_COLUMNA('Nro. de Pr&eacute;stamo<br>/ Titular:',120,'left','S'); -- agrego la columna etiqueta
        elsif v_cod_mod_contra = 5 then
          pag_htm.PR_COLUMNA('Nro. Cta. Tarjeta:',120,'left','S'); -- agrego la columna etiqueta
        else
          pag_htm.PR_COLUMNA('Cta. Contraparte:',120,'left','S'); -- agrego la columna etiqueta
        end if;
        pag_htm.PR_COLUMNA(nvl(v_nro_tar_contra,v_cta_contra_formateada) ||' - ' ||v_denominacion,310); -- agrego la columna del nro de cuenta
        pag_htm.PR_COLUMNA('Tipo:',10,'left','S');
        pag_htm.PR_COLUMNA(fue_obt_titulo(fug_obt_des_modal(v_cod_mod_contra,v_cod_mad_contra)),null,'left'); 
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
      
      if v_cotizacion = 1 and v_cot_contra is not null then
        pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
          pag_htm.PR_FILA('S'); -- ABRO LA FILA
          pag_htm.PR_COLUMNA('Cotizaci&oacute;n: ',120,'left','S'); -- agrego la columna etiqueta
          pag_htm.PR_COLUMNA(to_char(v_cot_contra,'999,999,999,999.99'),153,'right');
          pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
          pag_htm.PR_FILA('N'); -- CIERRO LA FILA    
        pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
        
        pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
          pag_htm.PR_FILA('S'); -- ABRO LA FILA
          pag_htm.PR_COLUMNA('Monto: ',120,'left','S'); -- agrego la columna etiqueta
          pag_htm.PR_COLUMNA(v_cod_mon_contra,30,'left');
          pag_htm.PR_COLUMNA(to_char(v_mto_contra,'999,999,999,999.99'),120,'right');
          pag_htm.PR_COLUMNA(); -- agrego la columna etiqueta
          pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
      end if;      
    end if;
    pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA(null,null); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Ingresado por:',170,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(fue_obt_nom_persona(v_cod_per_ingreso),null,'left'); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Autorizaciones Requeridas:',170,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(v_can_aut_requeridas,null,'left'); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_FILA('S'); -- ABRO LA FILA
      pag_htm.PR_COLUMNA('Autorizaciones Registradas:',170,'left','S'); -- agrego la columna etiqueta
      pag_htm.PR_COLUMNA(nvl(v_can_aut_requeridas,0) - nvl(v_can_aut_faltantes,0),null,'left'); -- agrego la columna del nro de cuenta
      pag_htm.PR_FILA('N'); -- CIERRO LA FILA
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
    pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal

    --detalles del movimiento
    if v_cod_tip_mensaje = '070' and (v_estado <> 'A' or p_estado = 'P') then --hay detalles de sueldos
      declare
        v_sino varchar2(1) := 'N';
      begin
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('DETALLES DE CREDITOS',NULL,'center','S'); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        --BBVADES-2376
        if v_estado = 'P' then
          v_sino := 'S';
        elsif v_estado = 'C' then 
          -- verifico que aun este en movimiento pendiente para informar,
          -- para entes Batch y Requerimiento
          for csue in c_sue_pendientes(v_dato, v_referencia) loop
            v_sino := 'S';
            exit;
          end loop;
        end if;
        if v_sino = 'S' then
           if v_tip_pro_sueldo='B' then
              pag_htm.PR_FILA('S'); -- ABRO LA FILA
              pag_htm.PR_COLUMNA('<hr width=630><br/>** El pago se realizara en el cierre diario.',NULL,'right','S'); -- agrego la columna etiqueta
              pag_htm.PR_FILA('N'); -- CIERRO LA FILA
           elsif v_tip_pro_sueldo='R' then
              pag_htm.PR_FILA('S'); -- ABRO LA FILA
              pag_htm.PR_COLUMNA('<hr width=630><br/>** El pago se realizara a requerimiento.',NULL,'right','S'); -- agrego la columna etiqueta
              pag_htm.PR_FILA('N'); -- CIERRO LA FILA
           end if;
        end if;
        --Fin BBVADES-2376
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
      pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal   
      
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Cuenta',133,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('Nombre de Cuenta',300,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('&nbsp;&nbsp;Mon.',15,'left','S'); -- agrego la columna 
        --pag_htm.PR_COLUMNA('Débito',150,'right','S'); -- agrego la columna 
        pag_htm.PR_COLUMNA('Monto',180,'right','S'); -- agrego la columna 
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        
        if v_estado = 'P' or p_estado = 'P' or v_sino = 'S' then
          for reg in c_sue_pendientes(v_dato, v_referencia) loop
            v_cont := v_cont + 1;
            if v_cont > 100 then
              v_retorno := v_retorno || pag_htm.v_texto;
              pag_htm.v_texto := null;
              v_cont := 0;
            end if;

            pag_htm.PR_FILA('S'); -- ABRO LA FILA
            pag_htm.PR_COLUMNA(reg.nro_cuenta,133,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(reg.denominacion,300,'left'); -- agrego la columna           
            pag_htm.PR_COLUMNA('&nbsp;&nbsp;'||reg.cod_moneda,15,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),180,'right'); -- agrego la columna 
            pag_htm.PR_FILA('N'); -- CIERRO LA FILA
          end loop;
        elsif v_estado = 'C' then
          for reg in c_sue_confirmados(v_dato, v_referencia) loop
            v_cont := v_cont + 1;
            if v_cont > 100 then
              v_retorno := v_retorno || pag_htm.v_texto;
              pag_htm.v_texto := null;
              v_cont := 0;
            end if;

            pag_htm.PR_FILA('S'); -- ABRO LA FILA
            pag_htm.PR_COLUMNA(reg.nro_cuenta,133,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(reg.denominacion,300,'left'); -- agrego la columna           
            pag_htm.PR_COLUMNA('&nbsp;&nbsp;'||reg.cod_moneda,15,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),180,'right'); -- agrego la columna 
            pag_htm.PR_FILA('N'); -- CIERRO LA FILA
          end loop;
        end if;
      exception 
         when others then
         raise_application_error(-20003,'Long. '||length(pag_htm.v_texto)||' Cont:'||v_cont||sqlerrm);
      end;          
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
      v_retorno := v_retorno || pag_htm.v_texto;
      pag_htm.v_texto := fuw_imp_sue_errores(v_dato, v_referencia, 'S');
      pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal 
    end if;-- find detalles    

    --detalles del movimiento
    if v_cod_tip_mensaje = '075' and (v_estado <> 'A' or p_estado = 'P') then --hay detalles de proveedores
     begin 
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('DETALLES DE PAGOS',NULL,'center','S'); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
      pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal   
      
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Nro.Orden',80,'left','S'); -- agrego la columna etiqueta
         pag_htm.PR_COLUMNA('Tipo Pago',80,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('Beneficiario',300,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('&nbsp;&nbsp;Mon.',15,'left','S'); -- agrego la columna 
        --pag_htm.PR_COLUMNA('Débito',150,'right','S'); -- agrego la columna 
        pag_htm.PR_COLUMNA('Monto',180,'right','S'); -- agrego la columna 
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        
        if v_estado = 'P' or p_estado = 'P' then
          for reg in pagos(v_dato, v_referencia) loop
  
            -- Truquito para que cada 100 registros se pase a la variable v_retorno
            -- porque pag_htm.v_texto solo soporta hasta 32767 caracteres.
            v_cont := v_cont + 1;
            if v_cont > 100 then
              v_retorno := v_retorno || pag_htm.v_texto;
              pag_htm.v_texto := null;
              v_cont := 0;
            end if;
          
            pag_htm.PR_FILA('S'); -- ABRO LA FILA
            pag_htm.PR_COLUMNA(reg.nro_orden,80,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(reg.for_pago,80,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(reg.denominacion,300,'left'); -- agrego la columna           
            pag_htm.PR_COLUMNA('&nbsp;&nbsp;'||reg.cod_moneda,15,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),180,'right'); -- agrego la columna 
            pag_htm.PR_FILA('N'); -- CIERRO LA FILA
          end loop;
        elsif v_estado = 'C' then
          for reg in c_pro_pagados(v_dato, v_referencia) loop  
            -- Truquito para que cada 100 registros se pase a la variable v_retorno
            -- porque pag_htm.v_texto solo soporta hasta 32767 caracteres.
            v_cont := v_cont + 1;
            if v_cont > 100 then
              v_retorno := v_retorno || pag_htm.v_texto;
              pag_htm.v_texto := null;
              v_cont := 0;
            end if;
          
            pag_htm.PR_FILA('S'); -- ABRO LA FILA
            pag_htm.PR_COLUMNA(reg.nro_orden,80,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(reg.for_pago,80,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(reg.denominacion,300,'left'); -- agrego la columna           
            pag_htm.PR_COLUMNA('&nbsp;&nbsp;'||reg.cod_moneda,15,'left'); -- agrego la columna 
            pag_htm.PR_COLUMNA(to_char(reg.monto,'999,999,999,999.99'),180,'right'); -- agrego la columna 
            pag_htm.PR_FILA('N'); -- CIERRO LA FILA
          end loop;
        end if;
                
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA    
      pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal 
     exception
        when others then
          raise_application_error(-20003,'Long. '||length(pag_htm.v_texto)||' Cont:'||v_cont||sqlerrm);
     end;
    end if;-- find detalles 

   --ver si hay detalles
    for reg in detalles loop
      v_existe := 'S';
      exit;
    end loop;
    --detalles del movimiento
    if v_existe = 'S' then --hay detalles
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('DETALLE DE AUTORIZACIONES',NULL,'center','S'); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA
      pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal   
      
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
        pag_htm.PR_FILA('S'); -- ABRO LA FILA
        pag_htm.PR_COLUMNA('Nombre',240,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('Fecha y Hora',120,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('Comentario',250,'left','S'); -- agrego la columna etiqueta
        pag_htm.PR_COLUMNA('Estado',20,'center','S'); -- agrego la columna etiqueta
        pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        
        for reg in detalles loop
          pag_htm.PR_FILA('S'); -- ABRO LA FILA
          pag_htm.PR_COLUMNA(fue_obt_titulo(reg.nombre),240,'left'); -- agrego la columna etiqueta
          pag_htm.PR_COLUMNA(to_char(reg.fec_hora,'dd/mm/yyyy hh24:mi:ss'),120,'left'); -- agrego la columna etiqueta
          pag_htm.PR_COLUMNA(reg.observacion,250,'left'); -- agrego la columna etiqueta
          pag_htm.PR_COLUMNA(reg.accion,20,'center'); -- agrego la columna etiqueta
          pag_htm.PR_FILA('N'); -- CIERRO LA FILA
        end loop;
                
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA    
      pag_htm.pr_texto('<hr width=630>'); --dibuja una línea horizontal 
    end if;-- fin detalles    
    
    --sólo si recibe imprimir comentario
    if p_imp_comentario = 'S' then
      pag_htm.PR_TABLA('S',630,null,0); -- DEFINO LA TABLA
          pag_htm.PR_FILA('S'); -- ABRO LA FILA
          pag_htm.PR_COLUMNA('Ingrese Comentario:',140,'left','S'); -- agrego la columna etiqueta
          pag_htm.PR_COLUMNA('<input type="text" name="comentario" size=78>',null,'left'); -- agrego la columna etiqueta
          pag_htm.PR_FILA('N'); -- CIERRO LA FILA
      pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA      
    end if;
  end if;-- sin error
---
  --pag_htm.PR_CUERPO('N'); -- cierro el body

 -- pag_htm.PR_PIE; -- pie del html
  v_retorno := v_retorno || pag_htm.v_texto;
  return v_retorno;
  
 -- return pag_htm.v_texto;
end FUW_IMP_MOV_PENDIENTE;
/

