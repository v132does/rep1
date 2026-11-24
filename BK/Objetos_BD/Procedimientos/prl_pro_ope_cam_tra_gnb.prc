CREATE OR REPLACE PROCEDURE IT.PRL_PRO_OPE_CAM_TRA_GNB (P_FEC_ACTUAL       IN ge_movimientos.fecha%TYPE,
                                                     P_HORA             IN VARCHAR2,
                                                     P_COD_USUARIO      IN VARCHAR2,
                                                     P_NRO_OPERACION    IN NUMBER,
                                                     P_TIPO             IN VARCHAR2,
                                                     P_ES_MOV_NOC       IN VARCHAR2) IS

v_hora              varchar2(08);
PROCEDURE PR_PRO_OPE_COM_TRA_GNB;
PROCEDURE PR_PRO_OPE_VTA_TRA_GNB;

PROCEDURE PR_PRO_OPE_VTA_TRA_GNB IS
v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modulo        NUMBER(04);
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
--v_hora              varchar2(08);
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_cuenta        ge_cuentas.nro_cuenta%type;
v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;
cursor cur_datos is
     --- movimientos de transferencias internas
   select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
          a.nro_cuenta nro_cuenta, 
          nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
          '_TRA_GNB'
     from ge_movimientos b, ge_movimientos a
    where a.cod_tra_padre =411  -- transferencias internas
      and a.estado = 'N'
      and a.cod_transaccion = 503
      and a.monto <> 0
      --and b.cod_mad_padre = 455
      and b.estado = 'N'
      and b.cod_transaccion = 74
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      and b.nro_documento = P_NRO_OPERACION
      AND B.HORA = P_HORA
      AND B.COD_USUARIO = P_COD_USUARIO;

cursor cur_movs_noc is
     --- movimientos nocturnos de transferencias internas
   select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
          a.nro_cuenta nro_cuenta, 
          nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
          '_TRA_GNB'
     from ge_movimientos_noc b, ge_movimientos_noc a
    where a.cod_tra_padre =411  -- transferencias internas
      and a.estado = 'N'
      and a.cod_transaccion = 503
      and a.monto <> 0
      --and b.cod_mad_padre = 455
      and b.estado = 'N'
      and b.cod_transaccion =74
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      and b.nro_documento = P_NRO_OPERACION
      AND B.HORA = P_HORA
      AND B.COD_USUARIO = P_COD_USUARIO;

BEGIN
      --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
     v_hora := to_char(sysdate,'HH24:MI:SS');
     --wa:para pk
     v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,p_es_mov_noc);
     
     ----movimientos de venta en ge_movimientos
     if p_es_mov_noc = 'N' then
     
        if cur_datos%isopen then
            close cur_datos;
        end if;
        open cur_datos;
            
          loop
            
             fetch cur_datos
             into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto, v_nro_cuenta, v_cotizacion,
                    v_cod_tra_padre,v_referencia;
       
             
             exit when cur_datos%notfound;
              
              PRL_PRO_POSIC_CAM_TRA_GNB(p_fec_actual,
                                        v_hora,
                                        v_cod_moneda,
                                        v_cod_modulo,
                                        v_cod_oficina,
                                        v_monto,
                                        v_nro_cuenta,
                                        v_cotizacion,
                                        v_cod_tra_padre,
                                        v_referencia,
                                        null,
                                        p_tipo,
                                        p_es_mov_noc);
        end loop;
        if cur_datos%isopen then
           close cur_datos;
        end if;
    elsif p_es_mov_noc = 'S' then
    
      ---movimientos nocturnos de venta en ge_movimientos_noc
      if cur_movs_noc%isopen then
         close cur_movs_noc;
      end if;
      
      open cur_movs_noc;
      loop
          fetch cur_movs_noc
           into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto, v_nro_cuenta, v_cotizacion,
                v_cod_tra_padre,v_referencia;
          exit when cur_movs_noc%notfound;
          
          PRL_PRO_POSIC_CAM_TRA_GNB(p_fec_actual,
                                          v_hora,
                                          v_cod_moneda,
                                          v_cod_modulo,
                                          v_cod_oficina,
                                          v_monto,
                                          v_nro_cuenta,
                                          v_cotizacion,
                                          v_cod_tra_padre,
                                          v_referencia,
                                          null,
                                          p_tipo,
                                          p_es_mov_noc);
      end loop;
      if cur_movs_noc%isopen then
         close cur_movs_noc;
      end if;
    end if;
  
  
  --Insertamos una Referencia al boleteo en caso de reversion--
    insert into BA_COD_REFERENCIAS
  (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA)
  values
  ('DAT_OPE_RELACION', 'Operaciones Relacionadas',  V_HORA, P_HORA, null);

END;


---RAMON PAVON--
/*Proceso que registra movimientos automaticos de compra por operaciones diarias
por Clientes en moneda extranjera. Es llamado desde PR_PRO_COMPRAS - AP 741 - SDC*/
PROCEDURE PR_PRO_OPE_COM_TRA_GNB IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modulo        NUMBER(04);
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
--v_hora              varchar2(08);
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_cuenta        ge_cuentas.nro_cuenta%type;
v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;

CURSOR CUR_DATOS IS
    select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
           b.nro_cuenta nro_cuenta,
           nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
           '_TRA_GNB'
    from  ge_movimientos b, ge_movimientos a
    where a.cod_tra_padre =411 -- transferencias internas
      and a.estado = 'N'
      and a.cod_transaccion = 74
      and a.monto <> 0
      and b.estado = 'N'
      and b.cod_transaccion =503
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      and b.nro_documento = P_NRO_OPERACION
      AND B.HORA = P_HORA
      AND B.COD_USUARIO = P_COD_USUARIO;
      
--movimientos nocturnos
CURSOR cur_movs_noc IS
    select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
           b.nro_cuenta nro_cuenta,
           nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
           '_TRA_GNB'
    from  ge_movimientos_noc b, ge_movimientos_noc a
    where a.cod_tra_padre =411 -- transferencias internas
      and a.estado = 'N'
      and a.cod_transaccion = 74
      and a.monto <> 0
      and b.estado = 'N'
      and b.cod_transaccion =503
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      and b.nro_documento = P_NRO_OPERACION
      AND B.HORA = P_HORA
      AND B.COD_USUARIO = P_COD_USUARIO;

BEGIN
  begin
    select cod_tip_ope_bcp
      into v_cod_tip_ope_bcp
      from lc_tip_operaciones
     where lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
  exception
    when others then v_cod_tip_ope_bcp := 'A19';
  end;
  ----------------------------------------------------------------

  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,p_es_mov_noc);

 
   ----movimientos de venta en ge_movimientos
     if p_es_mov_noc = 'N' then
     
        if cur_datos%isopen then
            close cur_datos;
        end if;
        open cur_datos;
            
          loop
            
             fetch cur_datos
             into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto, v_nro_cuenta, v_cotizacion,
                    v_cod_tra_padre,v_referencia;
       
             
             exit when cur_datos%notfound;
              
              PRL_PRO_POSIC_CAM_TRA_GNB(p_fec_actual,
                                        v_hora,
                                        v_cod_moneda,
                                        v_cod_modulo,
                                        v_cod_oficina,
                                        v_monto,
                                        v_nro_cuenta,
                                        v_cotizacion,
                                        v_cod_tra_padre,
                                        v_referencia,
                                        v_cod_tip_ope_bcp,
                                        p_tipo,
                                        p_es_mov_noc);
        end loop;
        if cur_datos%isopen then
           close cur_datos;
        end if;
        
    elsif p_es_mov_noc = 'S' then
    
      ---movimientos nocturnos de venta en ge_movimientos_noc
      if cur_movs_noc%isopen then
         close cur_movs_noc;
      end if;
      
      open cur_movs_noc;
      loop
          fetch cur_movs_noc
           into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto, v_nro_cuenta, v_cotizacion,
                v_cod_tra_padre,v_referencia;
          exit when cur_movs_noc%notfound;
          
          PRL_PRO_POSIC_CAM_TRA_GNB(p_fec_actual,
                                          v_hora,
                                          v_cod_moneda,
                                          v_cod_modulo,
                                          v_cod_oficina,
                                          v_monto,
                                          v_nro_cuenta,
                                          v_cotizacion,
                                          v_cod_tra_padre,
                                          v_referencia,
                                          v_cod_tip_ope_bcp,
                                          p_tipo,
                                          p_es_mov_noc);
      end loop;
      if cur_movs_noc%isopen then
         close cur_movs_noc;
      end if;
    end if;

  insert into BA_COD_REFERENCIAS
  (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA)
  values
  ('DAT_OPE_RELACION', 'Operaciones Relacionadas',  V_HORA, P_HORA, null);
END;

BEGIN
  IF P_TIPO = 'C' then --Compras--
     PR_PRO_OPE_COM_TRA_GNB;
  elsif P_TIPO = 'V' then --Ventas--
     PR_PRO_OPE_VTA_TRA_GNB;
  else
     raise_application_error(-20005,'Error. El Tipo debe ser C-Compra, o V-Venta. Verifique.');
  end if;
END;
/

