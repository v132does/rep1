CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_CON_CIDESA
(p_fecha in date,
 p_tipo in varchar2,
 p_cod_moneda in varchar2 )
IS
/**********************************************************
Programa: Generac. de arch. de conciliaciones para Cidesa
Valores de Tipo:
  -> Por transaccion en ge_movimientos (TRA)
  -> Por rubro en ge_movimientos (RUB)
  -> Ambos, transacciones y rubros (AMB)
********************************************************/
   v_texto                varchar2(32000) := null;
   v_monto                number(18,4)   := 0;
   v_monto_c              varchar2(30)   := null;
   v_fec_ope              varchar2(10)   := null;
   v_contador             number(6);
   v_fec_ant_informe      date;
   v_fec_actual           date;
   v_pos_ini_dia          number(18,2);
   v_pos_ini_dia_c        varchar2(30)   := null;
   v_pos_fin_dia          number(18,2);
   v_pos_fin_dia_c        varchar2(30)   := null;
   v_acumulado            number(18,2);
   v_sal_ini_con          number(18,2);
   v_sal_ini              number(18,2);
   v_cod_mon_bt           varchar2(30);
   v_cod_moneda           varchar2(30);
   v_nom_archivo          varchar2(100);
   v_cod_transaccion      NUMBER(30);
   v_bco_emisor           varchar2(30):= fug_obt_pardinamico('COD_BAN_CID_GNBF', NULL, NULL, null);
   v_bco_receptor         varchar2(30):= fug_obt_pardinamico('COD_BAN_CID_GNB', NULL, NULL, null);
   v_fec_anterior         date:= pag_cal.fu_obt_fec_ant_hab(p_fecha, NULL);
   v_cod_mon_local        ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   v_sal_fin_anterior     number(18,2);
   v_cod_rubro            varchar2(100);
   v_cod_rubro1           varchar2(100);
   v_tip_ope_cid          varchar2(30):= fug_obt_pardinamico('TIP_OPE_CID', NULL, NULL, p_cod_moneda);
   v_abreviatura          varchar2(30);
   v_concepto             varchar2(300);
   v_tipo                 varchar2(1):= null;
   v_tip_tra              varchar2(1):= null;
   v_tip_mov              varchar2(3):= null;
   v_nro_ope_cid          varchar2(100);
   v_lon_ref              number(10);
   v_pos_ini              number(10);
   v_lugar                varchar2(3000);
   v_nro_cuenta           varchar2(100);
   --Se parametriza longitud descripcion y nro transaccion para futuro desarrollo interno
   v_lon_max_des_cid      number(20);
   v_lon_max_nro_tra_cid  number(20):= nvl(fug_obt_pardinamico('LON_MAX_NRO_TRA_CID', NULL, NULL, null),10);
   V_COD_TRA_REL          varchar2(100);
   v_tip_sal_ini          varchar2(100);
   v_fec_ini_con          date:=  fug_obt_pardinamico('FEC_INI_CONCILIACIONES', NULL, NULL, null);
   --Parametros para excluir
   v_fec_anu_ini_conciliaciones       date:=  fug_obt_pardinamico('FEC_ANU_INI_CONCILIACIONES', NULL, NULL, null);
   v_fec_anu_fin_conciliaciones       date:=  fug_obt_pardinamico('FEC_ANU_FIN_CONCILIACIONES', NULL, NULL, null);
   v_cod_tra_anu_conciliaciones       varchar2(30):=  fug_obt_pardinamico('COD_TRA_ANU_CONCILIACIONES', NULL, NULL, null);
   v_cod_rub_anu_conciliaciones       varchar2(30):=  fug_obt_pardinamico('COD_RUB_ANU_CONCILIACIONES', NULL, NULL, null);
   v_procesar varchar2(10);

--Cursor de transacciones
   cursor c_transacciones is
     select a.val_minimo cod_transaccion,a.val_maximo as tipo
          from ba_cod_referencias a
            where a.dominio='TIP_TRA_CON_CIDESA'
             and upper(a.abreviatura)= upper(p_tipo);
--Cursor de Rubros
 cursor c_rubros is
      select null cod_transaccion,a.val_maximo as tipo
          from ba_cod_referencias a
            where a.dominio='TIP_RUB_CON_CIDESA'
                and upper(a.val_minimo)= upper(v_cod_rubro);

--Cursor de detalle de transacciones
   CURSOR c_det_datos_tra IS
      --Cursor datos día
      select  a.fecha fecha,
              a.concepto as concepto,
              a.nro_documento as nro_ope,
              a.monto importe,
              a.cod_moneda as cod_moneda,
              a.hora,
              a.cod_usuario,
              nvl(a.reversado,'N') reversado,
              a.tip_mov_rubro as tip_mov_rubro,
              a.fec_insercion,
              a.nro_cuenta,
              a.cod_transaccion,
              a.cod_rubro,
              a.cod_oficina,
              a.cod_ofi_origen,
                a.nro_caja
         from ge_movimientos A
            where a.fecha= p_fecha
              --and a.nro_cuenta is null
              and a.cod_moneda= v_cod_moneda
              and a.cod_transaccion= v_cod_transaccion
              and a.estado='N'
              --and nvl(a.reversado,'N')='N'  -- Se informan los reversados y no reversados
         union
           --historico
          select a.fecha fecha,
                a.concepto as concepto,
                a.nro_documento as nro_ope,
                a.monto importe,
                a.cod_moneda as cod_moneda,
                a.hora,
                a.cod_usuario,
                nvl(a.reversado,'N') reversado,
                a.tip_mov_rubro as tip_mov_rubro,
                a.fec_insercion,
                a.nro_cuenta,
                a.cod_transaccion,
                a.cod_rubro,
                a.cod_oficina,
                a.cod_ofi_origen,
                a.nro_caja
            from gv_movimientos A
                where a.fecha= p_fecha
                  --and a.nro_cuenta is NULL
                  and a.COD_MONEDA= v_cod_moneda
                  and a.cod_transaccion= v_cod_transaccion
                  and a.estado='N'
                  --and nvl(a.reversado,'N')='N'  -- Se informan los reversados y no reversados
             order by 10;

--Cursor de detalle de rubros
   CURSOR c_det_datos_rub IS
      --Cursor datos día
      select  a.fecha fecha,
              a.concepto as concepto,
              a.nro_documento as nro_ope,
              a.monto importe,
              a.cod_moneda as cod_moneda,
              a.hora,
              a.cod_usuario,
              nvl(a.reversado,'N') reversado,
              a.tip_mov_rubro as tip_mov_rubro,
              a.fec_insercion,
              a.nro_cuenta,
              a.cod_transaccion,
              a.cod_rubro,
              a.cod_oficina,
              a.cod_ofi_origen,
                a.nro_caja
         from ge_movimientos A
            where a.fecha= p_fecha
              --and a.nro_cuenta is null
              and a.cod_moneda= v_cod_moneda
              and a.cod_rubro= v_cod_rubro1
              and a.estado='N'
              --and nvl(a.reversado,'N')='N'  -- Se informan los reversados y no reversados
         union
           --historico
          select a.fecha fecha,
                a.concepto as concepto,
                a.nro_documento as nro_ope,
                a.monto importe,
                a.cod_moneda as cod_moneda,
                a.hora,
                a.cod_usuario,
                nvl(a.reversado,'N') reversado,
                a.tip_mov_rubro as tip_mov_rubro,
                a.fec_insercion,
                a.nro_cuenta,
                a.cod_transaccion,
                a.cod_rubro,
                a.cod_oficina,
                a.cod_ofi_origen,
                a.nro_caja
            from gv_movimientos A
                where a.fecha= p_fecha
                  --and a.nro_cuenta is NULL
                  and a.COD_MONEDA= v_cod_moneda
                  and a.cod_rubro = v_cod_rubro1
                  and a.estado='N'
                  --and nvl(a.reversado,'N')='N'  -- Se informan los reversados y no reversados
             order by 10;

BEGIN
  /*********  Inicio de proceso Principal***************/
  Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; end;
  --Validamos parametria
  v_lugar:= null;
  v_lugar:= 'Val.Par.Rec';
  if p_fecha is null or trunc(p_fecha)> trunc(v_fec_actual) then
     raise_application_error(-20000,'La fecha no puede ser nula ni mayor a la fecha actual del sistema');
  end if;
  if p_tipo is null  then
     raise_application_error(-20000,'Tipo no recibido');
  end if;

  if p_cod_moneda is null  then
     raise_application_error(-20000,'Moneda no recibida');
  end if;
  --Obtenemos lalongituda maxima de concepto
   begin
     select a.val_MAXIMO
        into v_lon_max_des_cid
          from ba_cod_referencias a
            where a.dominio='LON_CON_CONCEPTO'
             and upper(a.val_minimo)=upper(p_tipo);
    exception
        when no_data_found then
           v_lon_max_des_cid:=60;
    end;

  --Borramos lo generado para volver a cargar
  v_lugar:= 'Borrando datos anteriores';
  delete from mi_dat_cidesa x
    where x.fecha=p_fecha
       and x.cod_moneda_it= p_cod_moneda
       and x.tipo= p_tipo;
       commit;
     v_fec_ant_informe:= null;
     --En el campo val_minimo de la referencia TIP_CON_CIDESA se guarda las abreviaturas.
     v_abreviatura:=upper(p_tipo);
     v_sal_fin_anterior:=0;
     v_cod_rubro1:= null;
     v_cod_rubro:= null;
     v_sal_ini_con:=0;
     v_sal_ini:=0;
     v_acumulado:= 0;
     v_contador := 0;
     v_tip_mov:= null;
    --Obtenemos si es por rubro o por transaccion
    v_lugar:= 'Obt.Val.de Tipo de Conciliación:' ||upper(p_tipo);
    begin
     select a.val_maximo
        into v_tip_mov
          from ba_cod_referencias a
            where a.dominio='TIP_CON_CIDESA'
             and upper(a.val_minimo)=upper(p_tipo);
    exception
        when no_data_found then
           raise_application_error(-20000,'Tipo de Conc. No parametrizado: '||upper(p_tipo));
    end;

    if v_tip_mov IN ('RUB','AMB') THEN
         --Buscamos los rubros parametrizados acorde al tipo y moneda(Para Saldo Inicial)
         v_lugar:= 'Rubro No parametrizado, para la moneda: '||upper(p_cod_moneda)|| ' Tipo:'||p_tipo;
         begin
           select a.val_minimo
             into v_cod_rubro
              from ba_cod_referencias a
                where a.dominio='TIP_RUB_CON_CIDESA'
                 and a.val_maximo= p_cod_moneda
                 and a.abreviatura= p_tipo;
         exception
            when no_data_found then
              -- v_cod_rubro:= null;
              raise_application_error(-20000,'Rubro No parametrizado' );
         end;
    end if;

   --Para transacciones o ambos
   if v_tip_mov IN ('TRA','AMB') THEN

     --Cursor principal Cabecera
     FOR tra IN c_transacciones LOOP
         v_nro_ope_cid:=null;
         v_cod_transaccion:= null;
         v_cod_moneda:=p_cod_moneda;
         v_tip_tra:= null;
         --6100 USD/6300 EURO/6400 REAL/6500 PESO/6900 GS

         v_cod_mon_bt:= CASE v_cod_moneda
                              WHEN 'USD' THEN 6100
                              WHEN 'GS'  THEN 6900
                              WHEN 'EUR' THEN 6300
                              WHEN 'BRL' THEN 6400
                              WHEN 'ARS' THEN 6500
                              ELSE NULL END; --asignamos ya que se pasará antes que el pag_mig
         v_nom_archivo:= trim(v_abreviatura||v_bco_emisor||'_'||v_tip_ope_cid||'_'||TO_CHAR(p_fecha,'YYYY')||'_'||TO_CHAR(p_fecha,'MM')||'_'||TO_CHAR(p_fecha,'DD')||'.txt');
         v_cod_transaccion:= tra.cod_transaccion;
         v_tip_tra:= tra.tipo;
         V_COD_TRA_REL:=tra.cod_transaccion;
         --*************
         --Para verificar si cargamos io esta excluido
         if nvl(v_cod_tra_anu_conciliaciones,'xx') <> 'xx' THEN 
            if v_fec_anu_ini_conciliaciones is not null and v_fec_anu_fin_conciliaciones is not null then 
               if trunc(p_fecha) between trunc(v_fec_anu_ini_conciliaciones) and trunc(v_fec_anu_fin_conciliaciones) 
                   and v_cod_tra_anu_conciliaciones = to_char(v_cod_transaccion) then
                     --Aqui no debemos informar
                       v_cod_transaccion:=-1;
               end if;
            end if;
         
         end if;
         --************

      --Cursor de Detalles
      FOR dato IN c_det_datos_tra LOOP
          v_texto:= null;
          v_contador := v_contador + 1;
          v_monto:=0;
          v_monto_c := null;
          v_fec_ope := null;
          v_concepto:=null;
          v_tipo:= null;
          v_lon_ref:=0;
          v_pos_ini:=0;
          v_lugar:= 'Carg.Det.Tra. Nro.Ope: ' ||dato.nro_ope;
          v_tipo:= v_tip_tra;
          --Para los reversados
          if nvl(dato.importe,0) < 0 then
              --Es reversion, se cambia el tipo y monto positivo para Cidesa
              v_monto:= abs(dato.importe);
              v_tipo:= CASE v_tipo
                          when 'D' then 'C'
                          when 'C' then 'D'
                       END;
          elsif dato.cod_transaccion=791  then
             if nvl(dato.reversado,'N')='N' THEN
              v_tipo:='C';
              v_monto:= dato.importe;
              else
                 v_tipo:='D';
                 v_monto:= dato.importe;
              end if;
          else
              v_monto:= dato.importe;
          end if;
          --Tiene que tener el mismo rubro puente en ambs casos
          IF v_cod_rubro IS NULL THEN
                --oBTENEMOS EL CODIGO DE RUBRO DE LA TRANSACCION
                BEGIN
                  SELECT b.COD_RUBRO
                  INTO v_cod_rubro
                     FROM GE_TRANSACCIONES A , GE_TIP_ASIENTOS B
                       WHERE A.COD_TRANSACCION= DATO.COD_TRANSACCION
                        AND A.COD_TIP_ASIENTO=B.COD_TIP_ASIENTO
                        AND B.COD_MONEDA= DATO.COD_MONEDA
                        AND A.TIPO=B.TIP_MOVIMIENTO
                        AND ROWNUM=1;

                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     v_cod_rubro:= NULL;
                  WHEN OTHERS THEN
                     v_cod_rubro:= NULL;
                END;

          END IF;
     --v_monto_c := lpad(ltrim(to_char(v_monto,'999999999.99')),12,'0');
          v_monto_c := ltrim(to_char(v_monto,'999999999999999.99'));
          --Acumulamos monto
          if v_tipo='D' then
             v_acumulado   := v_acumulado - v_monto;
          elsif v_tipo='C' then
             v_acumulado   := v_acumulado + v_monto;
          end if;
          v_fec_ope     := to_char(dato.fecha,'DDMMYYYY');
          --trabajamos el concepto 35 (max cidesa )para agilizar ubicación de error
          v_lugar:= 'Carg.Concepto. Nro.Ope: ' ||dato.nro_ope;
          --Buscamos si tiene Cta el movimiento
          v_nro_cuenta:= null;
          --Para concepto
          if UPPER(p_tipo)='TI' THEN

               if v_tipo = 'C' then
                     begin
                       select z.nro_cuenta
                         into v_nro_cuenta
                           from gv_movimientos z
                             where z.FECHA= dato.fecha
                               and z.hora= dato.hora
                               and z.COD_USUARIO= dato.cod_usuario
                               and z.NRO_CUENTA is not null
                               and z.NRO_SECUENCIA=1
                               and rownum=1;
                     exception
                        when no_data_found then
                           begin
                                 select z.nro_cuenta
                                   into v_nro_cuenta
                                     from GE_MOVIMIENTOS z
                                       where z.FECHA= dato.fecha
                                         and z.hora= dato.hora
                                         and z.COD_USUARIO= dato.cod_usuario
                                         and z.NRO_CUENTA is not null
                                         and z.NRO_SECUENCIA=1
                                         and rownum=1;
                               exception
                                  when no_data_found then
                                    v_nro_cuenta:= null;
                                  when others then
                                    v_nro_cuenta:= null;
                              end;
                      when others then
                          v_nro_cuenta:= null;
                     end;
                elsif v_tipo = 'D' then
                        begin
                       select z.nro_cuenta
                         into v_nro_cuenta
                           from gv_movimientos z
                             where z.FECHA= dato.fecha
                               and z.hora= dato.hora
                               and z.COD_USUARIO= dato.cod_usuario
                               and z.NRO_CUENTA is not null
                               and z.NRO_SECUENCIA=2
                               and rownum=1;
                     exception
                        when no_data_found then
                           begin
                                 select z.nro_cuenta
                                   into v_nro_cuenta
                                     from GE_MOVIMIENTOS z
                                       where z.FECHA= dato.fecha
                                         and z.hora= dato.hora
                                         and z.COD_USUARIO= dato.cod_usuario
                                         and z.NRO_CUENTA is not null
                                         and z.NRO_SECUENCIA=2
                                         and rownum=1;
                               exception
                                  when no_data_found then
                                    v_nro_cuenta:= null;
                                  when others then
                                    v_nro_cuenta:= null;
                              end;
                      when others then
                          v_nro_cuenta:= null;
                     end;




                end if;

                --el concepto debe ser ( cuenta del cliente  – hora – usuario )
              v_concepto:= trim(substr(trim(v_nro_cuenta||'-'||dato.hora||'-'||dato.cod_usuario),1,v_lon_max_des_cid))   ;
          ELSIF UPPER(p_tipo)='TC' THEN
                --( usuario – número de caja – sucursal )
              v_concepto:= trim(substr(trim(dato.cod_usuario||'-'||dato.nro_caja||'-'||dato.cod_oficina),1,v_lon_max_des_cid)) ;
          ELSIF UPPER(p_tipo)='TM' THEN
               -- ( usuario – sucursal – hora )
              v_concepto:= trim(substr(trim(dato.cod_usuario||'-'||dato.cod_oficina||'-'||dato.HORA),1,v_lon_max_des_cid)) ;
          ELSIF UPPER(p_tipo)='TE' THEN
               -- ( NRO_DOCUMENTO – hORA- USUARIO )
              v_concepto:= trim(substr(trim(dato.Nro_Ope||'-'||dato.HORA||'-'||dato.cod_usuario),1,v_lon_max_des_cid)) ;
          ELSIF UPPER(p_tipo)='DH' THEN
               -- En los créditos (“C,”) el concepto debe ser ( cuenta del cliente – usuario – hora )
               -- En los débitos (“D,”) el concepto debe ser ( cuenta de cliente – usuario – hora )

               IF DATO.COD_TRANSACCION= 791 THEN
                    begin
                       select z.nro_cuenta
                         into v_nro_cuenta
                           from gv_movimientos z
                             where z.FECHA= dato.fecha
                               and z.hora= dato.hora
                               and z.COD_USUARIO= dato.cod_usuario
                               and z.NRO_CUENTA is not null
                               and z.NRO_SECUENCIA=-998
                               and rownum=1;
                     exception
                        when no_data_found then
                           begin
                                 select z.nro_cuenta
                                   into v_nro_cuenta
                                     from GE_MOVIMIENTOS z
                                       where z.FECHA= dato.fecha
                                         and z.hora= dato.hora
                                         and z.COD_USUARIO= dato.cod_usuario
                                         and z.NRO_CUENTA is not null
                                          and z.NRO_SECUENCIA=-998
                                          and rownum=1;
                               exception
                                  when no_data_found then
                                    v_nro_cuenta:= null;
                                  when others then
                                    v_nro_cuenta:= null;
                              end;
                      when others then
                          v_nro_cuenta:= null;
                     end;


               ELSIF v_tipo = 'C' then
                    begin
                       select z.nro_cuenta
                         into v_nro_cuenta
                           from gv_movimientos z
                             where z.FECHA= dato.fecha
                               and z.hora= dato.hora
                               and z.COD_USUARIO= dato.cod_usuario
                               and z.NRO_CUENTA is not null
                               and z.NRO_SECUENCIA=1
                               and rownum=1;
                     exception
                        when no_data_found then
                           begin
                                 select z.nro_cuenta
                                   into v_nro_cuenta
                                     from GE_MOVIMIENTOS z
                                       where z.FECHA= dato.fecha
                                         and z.hora= dato.hora
                                         and z.COD_USUARIO= dato.cod_usuario
                                         and z.NRO_CUENTA is not null
                                          and z.NRO_SECUENCIA=1
                                          and rownum=1;
                               exception
                                  when no_data_found then
                                    v_nro_cuenta:= null;
                                  when others then
                                    v_nro_cuenta:= null;
                              end;
                      when others then
                          v_nro_cuenta:= null;
                     end;



               elsif v_tipo = 'D' then
                    begin
                       select z.nro_cuenta
                         into v_nro_cuenta
                           from gv_movimientos z
                             where z.FECHA= dato.fecha
                               and z.hora= dato.hora
                               and z.COD_USUARIO= dato.cod_usuario
                               and z.NRO_CUENTA is not null
                               and z.NRO_SECUENCIA=-998
                               and rownum=1;
                     exception
                        when no_data_found then
                           begin
                                 select z.nro_cuenta
                                   into v_nro_cuenta
                                     from GE_MOVIMIENTOS z
                                       where z.FECHA= dato.fecha
                                         and z.hora= dato.hora
                                         and z.COD_USUARIO= dato.cod_usuario
                                         and z.NRO_CUENTA is not null
                                          and z.NRO_SECUENCIA=-998
                                          and rownum=1;
                               exception
                                  when no_data_found then
                                    v_nro_cuenta:= null;
                                  when others then
                                    v_nro_cuenta:= null;
                              end;
                      when others then
                          v_nro_cuenta:= null;
                     end;

               end if;


              v_concepto:= trim(substr(trim(v_nro_cuenta||'-'||dato.cod_usuario||'-'||dato.HORA),1,v_lon_max_des_cid)) ;
           elsif UPPER(p_tipo)='TE' THEN
                   v_concepto:= trim(substr(trim(dato.cod_usuario),1,v_lon_max_des_cid))   ;

           else
                  v_concepto:= trim(substr(trim(dato.hora||'-'||dato.cod_usuario),1,v_lon_max_des_cid))   ;
           END IF;


          --Cortamos el Numero de Operacion a 10 (max cidesa)
          v_lugar:= 'Carg.Nro.Tra.Cid. Nro.Ope: ' ||dato.nro_ope;
          v_lon_ref:= LENGTH(dato.nro_ope);
          if v_lon_ref > v_lon_max_nro_tra_cid then
             -- Si es mayor a 10 se toman los 10 finales
             v_pos_ini:= v_lon_ref - v_lon_max_nro_tra_cid ;
             v_nro_ope_cid:= trim(substr(dato.nro_ope,v_pos_ini,v_lon_max_nro_tra_cid));
          else
             --si es hasta 10, no se ajusta
             v_nro_ope_cid:= trim(dato.nro_ope);
          end if;

          --Armamos el texto
          v_lugar:= 'Al armar texto. Nro.Ope: ' ||dato.nro_ope;
          v_texto := rpad(v_tipo||','||v_fec_ope||','||v_fec_ope||','||v_concepto||','||v_nro_ope_cid||','||v_monto_c,80,' ');

          -- Insertamos en la tabla
          v_lugar:= 'Al insertar en la tabla. Nro.Ope: ' ||dato.nro_ope;
          insert into mi_dat_cidesa(fecha, registro, orden,  cod_moneda_bt, cod_moneda_it, nom_archivo,Tipo,
                        fec_mov,hor_mov,usu_mov,monto,deb_cre,reversado,tip_ope_cid,
                        nro_cuenta, cod_rubro,cod_transaccion, concepto,
                        nro_referencia, nro_ref_cidesa, cod_oficina, cod_ofi_origen )
                             values (dato.fecha, v_texto,v_contador,v_cod_mon_bt,v_cod_moneda,v_nom_archivo,upper(p_tipo),
                         dato.fecha,dato.hora,dato.cod_usuario, v_monto, v_tipo, dato.reversado,v_tip_ope_cid,
                         dato.nro_cuenta, dato.cod_rubro,dato.cod_transaccion, dato.concepto,
                         dato.nro_ope, v_nro_ope_cid , dato.cod_oficina, dato.cod_ofi_origen );
        END LOOP;
      END LOOP;
  END IF;
  --Para rubros o ambos
  IF v_tip_mov IN ('RUB','AMB') THEN
    --Cursor principal Cabecera
    FOR tra IN c_rubros LOOP
         v_nro_ope_cid:=null;
         v_cod_transaccion:= null;
         v_cod_moneda:=p_cod_moneda;
         v_cod_rubro1:= null;
         v_cod_mon_bt:= CASE v_cod_moneda
                              WHEN 'USD' THEN 6100
                              WHEN 'GS'  THEN 6900
                              WHEN 'EUR' THEN 6300
                              WHEN 'BRL' THEN 6400
                              WHEN 'ARS' THEN 6500
                              ELSE NULL END; --asignamos ya que se pasará antes que el pag_mig
         v_nom_archivo:= trim(v_abreviatura||v_bco_emisor||'_'||v_tip_ope_cid||'_'||TO_CHAR(p_fecha,'YYYY')||'_'||TO_CHAR(p_fecha,'MM')||'_'||TO_CHAR(p_fecha,'DD')||'.txt');
         v_cod_rubro1:= v_cod_rubro;
         
         --*************
         --Para verificar si cargamos io esta excluido
         if nvl(v_cod_rub_anu_conciliaciones,'xx') <> 'xx' THEN 
            if v_fec_anu_ini_conciliaciones is not null and v_fec_anu_fin_conciliaciones is not null then 
               if trunc(p_fecha) between trunc(v_fec_anu_ini_conciliaciones) and trunc(v_fec_anu_fin_conciliaciones) 
                   and v_cod_rub_anu_conciliaciones = to_char(v_cod_rubro1) then
                     --Aqui no debemos informar
                       v_cod_rubro1:='-1';
               end if;
            end if;
         
         end if;
             --Cursor de Detalles
            FOR dato IN c_det_datos_rub LOOP
                  v_texto:= null;
                  v_contador := v_contador + 1;
                  v_monto:=0;
                  v_monto_c := null;
                  v_fec_ope := null;
                  v_concepto:=null;
                  v_tipo:= null;
                  v_tipo:= dato.tip_mov_rubro;
                  v_lon_ref:=0;
                  v_pos_ini:=0;
                  v_lugar:= 'Carg.Det.Rub. Nro.Ope: ' ||dato.nro_ope;

                  --Para los reversados
                  if nvl(dato.importe,0) < 0 then
                      --Es reversion, se cambia el tipo y monto positivo para Cidesa
                      v_monto:= abs(dato.importe);
                      v_tipo:= CASE v_tipo
                                  when 'D' then 'C'
                                  when 'C' then 'D'
                               END;
                  else
                      v_monto:= dato.importe;
                  end if;

                  --v_monto_c := lpad(ltrim(to_char(v_monto,'999999999.99')),12,'0');
                  v_monto_c := ltrim(to_char(v_monto,'999999999999999.99'));
                  --Acumulamos monto
                  if v_tipo='D' then
                     v_acumulado   := v_acumulado - v_monto;
                  elsif v_tipo='C' then
                     v_acumulado   := v_acumulado + v_monto;
                  end if;
                  v_fec_ope     := to_char(dato.fecha,'DDMMYYYY');

                --Buscamos si tiene Cta el movimiento
                        /*  v_nro_cuenta:= null;
                          If nvl(nvl(dato.nro_cuenta,dato.cod_rubro),'-1')='-1' then
                                 begin
                                     select z.nro_cuenta
                                       into v_nro_cuenta
                                         from gv_movimientos z
                                           where z.FECHA= dato.fecha
                                             and z.hora= dato.hora
                                             and z.COD_USUARIO= dato.cod_usuario
                                             and z.NRO_CUENTA is not null
                                             and rownum=1;
                                   exception
                                      when no_data_found then
                                         begin
                                               select z.nro_cuenta
                                                 into v_nro_cuenta
                                                   from GE_MOVIMIENTOS z
                                                     where z.FECHA= dato.fecha
                                                       and z.hora= dato.hora
                                                       and z.COD_USUARIO= dato.cod_usuario
                                                       and z.NRO_CUENTA is not null
                                                       and rownum=1;
                                             exception
                                                when no_data_found then
                                                  v_nro_cuenta:= null;
                                                when others then
                                                  v_nro_cuenta:= null;
                                            end;
                                    when others then
                                        v_nro_cuenta:= null;
                                   end;
                          else
                             v_nro_cuenta:=nvl(dato.nro_cuenta,dato.cod_rubro);
                          end if;*/



                  --trabajamos el concepto 35 (max cidesa )para agilizar ubicación de error
                  v_lugar:= 'Carg.Concepto. Nro.Ope: ' ||dato.nro_ope;
                  --Para concepto
                if UPPER(p_tipo)='TI' THEN


                           begin
                             select z.nro_cuenta
                               into v_nro_cuenta
                                 from gv_movimientos z
                                   where z.FECHA= dato.fecha
                                     and z.hora= dato.hora
                                     and z.COD_USUARIO= dato.cod_usuario
                                     and z.NRO_CUENTA is not null
                                     and z.NRO_SECUENCIA=1
                                     and rownum=1;
                           exception
                              when no_data_found then
                                 begin
                                       select z.nro_cuenta
                                         into v_nro_cuenta
                                           from GE_MOVIMIENTOS z
                                             where z.FECHA= dato.fecha
                                               and z.hora= dato.hora
                                               and z.COD_USUARIO= dato.cod_usuario
                                               and z.NRO_CUENTA is not null
                                               and z.NRO_SECUENCIA=1
                                               and rownum=1;
                                     exception
                                        when no_data_found then
                                          v_nro_cuenta:= null;
                                        when others then
                                          v_nro_cuenta:= null;
                                    end;
                            when others then
                                v_nro_cuenta:= null;
                           end;

                      --el concepto debe ser ( cuenta del cliente  – hora – usuario )
                    v_concepto:= trim(substr(trim(v_nro_cuenta||'-'||dato.hora||'-'||dato.cod_usuario),1,v_lon_max_des_cid))   ;
                ELSIF UPPER(p_tipo)='TC' THEN
                      --( usuario – número de caja – sucursal )
                    v_concepto:= trim(substr(trim(dato.cod_usuario||'-'||dato.nro_caja||'-'||dato.cod_oficina),1,v_lon_max_des_cid)) ;
                ELSIF UPPER(p_tipo)='TM' THEN
                     -- ( usuario – sucursal – hora )
                    v_concepto:= trim(substr(trim(dato.cod_usuario||'-'||dato.cod_oficina||'-'||dato.HORA),1,v_lon_max_des_cid)) ;
                ELSIF UPPER(p_tipo)='TE' THEN
                  -- ( NRO_DOCUMENTO – hORA- USUARIO )
                  v_concepto:= trim(substr(trim(dato.Nro_Ope||'-'||dato.HORA||'-'||dato.cod_usuario),1,v_lon_max_des_cid)) ;

                ELSIF UPPER(p_tipo)='DH' THEN
                     -- En los créditos (“C,”) el concepto debe ser ( cuenta del cliente – usuario – hora )
                     -- En los débitos (“D,”) el concepto debe ser ( cuenta de cliente – usuario – hora )
                     if v_tipo = 'C' then
                          begin
                             select z.nro_cuenta
                               into v_nro_cuenta
                                 from gv_movimientos z
                                   where z.FECHA= dato.fecha
                                     and z.hora= dato.hora
                                     and z.COD_USUARIO= dato.cod_usuario
                                     and z.NRO_CUENTA is not null
                                     and z.NRO_SECUENCIA=1
                                     and rownum=1;
                           exception
                              when no_data_found then
                                 begin
                                       select z.nro_cuenta
                                         into v_nro_cuenta
                                           from GE_MOVIMIENTOS z
                                             where z.FECHA= dato.fecha
                                               and z.hora= dato.hora
                                               and z.COD_USUARIO= dato.cod_usuario
                                               and z.NRO_CUENTA is not null
                                                and z.NRO_SECUENCIA=1
                                                and rownum=1;
                                     exception
                                        when no_data_found then
                                          v_nro_cuenta:= null;
                                        when others then
                                          v_nro_cuenta:= null;
                                    end;
                            when others then
                                v_nro_cuenta:= null;
                           end;



                     elsif v_tipo = 'D' then
                          begin
                             select z.nro_cuenta
                               into v_nro_cuenta
                                 from gv_movimientos z
                                   where z.FECHA= dato.fecha
                                     and z.hora= dato.hora
                                     and z.COD_USUARIO= dato.cod_usuario
                                     and z.NRO_CUENTA is not null
                                     and z.NRO_SECUENCIA=-998
                                     and rownum=1;
                           exception
                              when no_data_found then
                                 begin
                                       select z.nro_cuenta
                                         into v_nro_cuenta
                                           from GE_MOVIMIENTOS z
                                             where z.FECHA= dato.fecha
                                               and z.hora= dato.hora
                                               and z.COD_USUARIO= dato.cod_usuario
                                               and z.NRO_CUENTA is not null
                                                and z.NRO_SECUENCIA=-998
                                                and rownum=1;
                                     exception
                                        when no_data_found then
                                          v_nro_cuenta:= null;
                                        when others then
                                          v_nro_cuenta:= null;
                                    end;
                            when others then
                                v_nro_cuenta:= null;
                           end;

                     end if;


                    v_concepto:= trim(substr(trim(v_nro_cuenta||'-'||dato.cod_usuario||'-'||dato.HORA),1,v_lon_max_des_cid)) ;
                elsif UPPER(p_tipo)='TE' THEN
                   v_concepto:= trim(substr(trim(dato.cod_usuario),1,v_lon_max_des_cid))   ;

                else
                  v_concepto:= trim(substr(trim(dato.hora||'-'||dato.cod_usuario),1,v_lon_max_des_cid))   ;
                END IF;

                 --Cortamos el Numero de Operacion a 10 (max cidesa)
                  v_lugar:= 'Carg.Nro.Tra.Cid. Nro.Ope: ' ||dato.nro_ope;
                  v_lon_ref:= LENGTH(dato.nro_ope);
                  if v_lon_ref > v_lon_max_nro_tra_cid then
                     -- Si es mayor a 10 se toman los 10 finales
                     v_pos_ini:= v_lon_ref - v_lon_max_nro_tra_cid ;
                     v_nro_ope_cid:= trim(substr(dato.nro_ope,v_pos_ini,v_lon_max_nro_tra_cid));
                  else
                     --si es hasta 10, no se ajusta
                     v_nro_ope_cid:= trim(dato.nro_ope);
                  end if;

                   --Armamos el texto
                   v_lugar:= 'Al armar texto. Nro.Ope: ' ||dato.nro_ope;
                   v_texto := rpad(v_tipo||','||v_fec_ope||','||v_fec_ope||','||v_concepto||','||v_nro_ope_cid||','||v_monto_c,80,' ');

                   -- Insertamos en la tabla
                   v_lugar:= 'Al insertar en la tabla. Nro.Ope: ' ||dato.nro_ope;
                   insert into mi_dat_cidesa(fecha, registro, orden,  cod_moneda_bt, cod_moneda_it, nom_archivo,Tipo,
                                fec_mov,hor_mov,usu_mov,monto,deb_cre,reversado,tip_ope_cid,
                                nro_cuenta, cod_rubro,cod_transaccion, concepto,
                                nro_referencia, nro_ref_cidesa, cod_oficina, cod_ofi_origen )
                                     values (dato.fecha, v_texto,v_contador,v_cod_mon_bt,v_cod_moneda,v_nom_archivo,upper(p_tipo),
                                 dato.fecha,dato.hora,dato.cod_usuario, v_monto, v_tipo, dato.reversado,v_tip_ope_cid,
                                 dato.nro_cuenta, dato.cod_rubro,dato.cod_transaccion, dato.concepto,
                                 dato.nro_ope, v_nro_ope_cid , dato.cod_oficina, dato.cod_ofi_origen );
              END LOOP;
      END LOOP;

  END IF;

       --if v_contador >= 1 then
          v_texto:= null;

           --Verificamos si hay registros menores a la fecha a informar en la tabla, para ver si es la primera vez
            select max(x.fecha)
              into v_fec_ant_informe
              from mi_dat_cidesa x
              where trunc(x.fecha) < trunc(p_fecha)
               and x.cod_moneda_it= p_cod_moneda
               and trunc(x.fecha)>= trunc(v_fec_ini_con)
               and x.tipo= p_tipo;


           v_lugar:= 'Saldo Inicial ';
          v_tip_sal_ini:= null;
           IF v_tip_mov IN ('TRA','AMB') THEN
               --Tiene que tener el mismo rubro puente en ambs casos
              IF v_cod_rubro IS NULL THEN
                     --oBTENEMOS EL CODIGO DE RUBRO DE LA TRANSACCION
                    BEGIN
                      SELECT b.COD_RUBRO
                      INTO v_cod_rubro
                         FROM GE_TRANSACCIONES A , GE_TIP_ASIENTOS B
                           WHERE A.COD_TRANSACCION= V_COD_TRA_REL
                            AND A.COD_TIP_ASIENTO=B.COD_TIP_ASIENTO
                            AND B.COD_MONEDA= p_cod_moneda
                            AND A.TIPO=B.TIP_MOVIMIENTO
                            AND ROWNUM=1;

                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                         v_cod_rubro:= NULL;
                      WHEN OTHERS THEN
                         v_cod_rubro:= NULL;
                    END;


             END IF;
          END IF;




           IF v_cod_rubro is not null then
               if v_fec_ant_informe is not null then
                   --Obtenemos saldo final del día anterior del rubro
                   if p_cod_moneda= v_cod_mon_local then
                        /*begin
                           select (nvl(a.sal_mon_loc_ant,0))
                           into v_pos_ini_dia
                             from cb_sal_consolidados_dia a
                                  where a.cod_rubro = v_cod_rubro
                                  and a.fecha = v_fec_anterior;
                            v_sal_ini_con:= v_pos_ini_dia;
                            v_tip_sal_ini:='SAL_CONTABLE';
                         exception
                          when no_data_found then*/
                             --Buscamos el saldo final de la tabla acumulada para informar
                             begin
                              select x.sal_fin_dia
                                  into v_sal_fin_anterior
                                  from mi_dat_cidesa x
                                  where trunc(x.fecha) = trunc(v_fec_ant_informe)
                                   and x.cod_moneda_it= p_cod_moneda
                                   and x.tipo= p_tipo
                                   and trunc(x.fecha)>= trunc(v_fec_ini_con)
                                   and x.sal_ini_dia is not null;
                                   v_tip_sal_ini:='SAL_FIN_DIA_ANTERIOR';
                              exception
                                when no_data_found then
                                   v_sal_fin_anterior:= 0;
                              end;
                              v_pos_ini_dia:=v_sal_fin_anterior;
                              v_sal_ini:= v_pos_ini_dia;
                         --end;
                   else
                         /*begin
                          select (nvl(a.sal_mon_rub_ant,0))
                            into v_pos_ini_dia
                              from cb_sal_consolidados_dia a
                                  where a.cod_rubro = v_cod_rubro
                                  and a.fecha = v_fec_anterior;
                              v_sal_ini_con:= v_pos_ini_dia;
                              v_tip_sal_ini:='SAL_CONTABLE';
                         exception
                           when no_data_found then*/
                                --Buscamos el saldo final de la tabla acumulada para informar
                                 begin
                                  select x.sal_fin_dia
                                      into v_sal_fin_anterior
                                      from mi_dat_cidesa x
                                      where trunc(x.fecha) = trunc(v_fec_ant_informe)
                                       and x.cod_moneda_it= p_cod_moneda
                                       and x.tipo= p_tipo
                                       and trunc(x.fecha)>= trunc(v_fec_ini_con)
                                       and x.sal_ini_dia is not null;
                                       v_tip_sal_ini:='SAL_FIN_DIA_ANTERIOR';
                                  exception
                                    when no_data_found then
                                       v_sal_fin_anterior:= 0;
                                  end;
                                  v_pos_ini_dia:=v_sal_fin_anterior;
                                  v_sal_ini:= v_pos_ini_dia;
                         --end;
                   end if;

               else
                 v_tip_sal_ini:='PRI_DIA_INF';
                 v_sal_ini_con:= 0;
                 v_pos_ini_dia:= 0;
               end if;
           else
              v_tip_sal_ini:='RUB_NO_ENCONTRADO';
              v_sal_ini_con:= 0;
              v_pos_ini_dia:= 0;
           end if;


           --Seteamos saldo inicial
           IF nvl(v_pos_ini_dia,0) >= 0 THEN
                v_pos_ini_dia_c       := ltrim(to_char(v_pos_ini_dia,'999999999999999.99'));
           ELSE
                v_pos_ini_dia_c       := '-'||ltrim(to_char(ABS(v_pos_ini_dia),'999999999999999.99'));
           END IF;
           --Calculamos saldo final
           v_lugar:= 'Saldo Final ';
           v_pos_fin_dia:=0;
           v_pos_fin_dia:= nvl(v_pos_ini_dia,0) + nvl(v_acumulado,0);
           v_pos_fin_dia_c:= null;
            IF v_pos_fin_dia >= 0 THEN

                v_pos_fin_dia_c       := ltrim(to_char(v_pos_fin_dia,'999999999999999.99'));
            ELSE
                v_pos_fin_dia_c       := '-'||ltrim(to_char(ABS(v_pos_fin_dia),'999999999999999.99'));
            END IF;
            if v_fec_ope is null then
              v_fec_ope     := to_char(p_fecha,'DDMMYYYY');
            end if;
            --Se guarda CABECERA
            v_lugar:= 'Carga.Cabecera ';
            v_tip_sal_ini:= v_tip_sal_ini ||'-'||v_tip_mov; -- De donde se obtuvo + tipo
            v_texto:= rpad('I,'||v_bco_emisor||','||v_bco_receptor ||','|| v_pos_ini_dia_c||','||v_pos_fin_dia_c||','||v_fec_ope||','||v_fec_ope||','||v_tip_ope_cid||','||v_contador,80,' ');
                insert into mi_dat_cidesa (fecha, registro,orden, cod_moneda_bt, cod_moneda_it,nom_archivo,Tipo,
                    sal_ini_dia, acu_dia,sal_fin_dia,Fec_Mov,Hor_Mov,Usu_Mov,
                    sal_ini_DIA_con,observacion)
                    values (p_fecha, v_texto, v_contador+1,v_cod_mon_bt,v_cod_moneda,v_nom_archivo,upper(p_tipo),
                    nvl(v_sal_ini,0),v_acumulado, v_pos_fin_dia, p_fecha,'00:00:00' ,user,
                    v_sal_ini_con,v_tip_sal_ini);
                   COMMIT;



EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(-20000,'Error -'||v_lugar||'-'||sqlerrm);
END;
/

