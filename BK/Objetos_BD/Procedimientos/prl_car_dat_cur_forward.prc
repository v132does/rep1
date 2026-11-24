create or replace procedure it.PRL_CAR_DAT_CUR_FORWARD is

  --//--Creado por rpavon--12/10/2017--//
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  --//--Para cargar datos de Curva de Forward desde--//
  --//--Publicacion en la pagna web de BCP--

  --Variables--
  v_lugar      varchar2(500);
  v_cod_moneda LC_FOR_CUR_FORWARD.cod_moneda%type;
  v_ano        LC_FOR_CUR_FORWARD.ano%type;
  v_semana     LC_FOR_CUR_FORWARD.semana%type;
  v_fec_desde  date;
  v_fec_hasta  date;
  v_can_control  number(6);
  v_for_ree_cur_forward ge_par_dinamicos.val_parametro%type;
begin
  v_lugar := 'Carga de Variables';
  v_cod_moneda := pag_gen.FU_OBT_MON_FUERTE;

  v_lugar := 'Extraer año,semana,fechas';
  SELECT TO_DATE(SUBSTR(UPPER(X.CAD_PLAZO),(INSTR(UPPER(X.CAD_PLAZO),'- FECHAS:'))+24,10),'DD/MM/YYYY')
    INTO V_FEC_DESDE
    FROM LC_FOR_CUR_FORWARD_TMP X
   WHERE UPPER(UPPER(X.CAD_PLAZO)) LIKE '%CURVA FORWARD - FECHA%';

  v_lugar := 'Actualizar registros';
  update LC_FOR_CUR_FORWARD_TMP x
     set x.cod_moneda = v_cod_moneda,
         --x.ano = v_ano,
         --x.semana = v_semana,
         x.fec_desde = v_fec_desde,
         --x.fec_hasta = v_fec_hasta,
         x.dia_plazo = to_number(x.cad_plazo),
         x.val_cotizacion = to_number(x.cad_cotizacion)
   where UPPER(UPPER(X.CAD_PLAZO)) NOT LIKE '%CURVA FORWARD%'
     and UPPER(UPPER(X.CAD_PLAZO)) NOT LIKE '%PLAZO%';

  v_lugar := 'Eliminar texto de cabecera - 2l';
  delete from LC_FOR_CUR_FORWARD_TMP x
   where UPPER(UPPER(X.CAD_PLAZO)) LIKE '%CURVA FORWARD%'
      or UPPER(UPPER(X.CAD_PLAZO)) LIKE '%PLAZO%';

  v_lugar := 'Validar';
  v_can_control := 0;
  select nvl(count(*),0)
    into v_can_control
    from LC_FOR_CUR_FORWARD y
   where y.COD_MONEDA = v_cod_moneda
     --and y.ANO = v_ano
     --and y.SEMANA = v_semana
     and y.FEC_DESDE = v_fec_desde;
     --and y.FEC_HASTA = v_fec_hasta;
   v_for_ree_cur_forward := nvl(fug_obt_pardinamico('FOR_REE_CUR_FORWARD'),'N');
   if ((nvl(v_can_control,0) > 0) and (v_for_ree_cur_forward = 'N')) then
      RAISE_APPLICATION_ERROR(-20000,'Error. '||
                             'Existen '||to_char(nvl(v_can_control,0))||' reg. de '||
                             'Fecha:'||to_char(v_fec_desde,'dd/mm/yyyy')||
                             --'-Año:'||to_char(v_ano)||
                             '-Mon:'||v_cod_moneda||
                             '-Para permitir recarga definir par.dinamico FOR_REE_CUR_FORWARD en S');
   end if;

   v_lugar := 'Insertar de temporal a produccion';
   if nvl(v_can_control,0) > 0 then
      delete from LC_FOR_CUR_FORWARD y
       where y.COD_MONEDA = v_cod_moneda
         --and y.ANO = v_ano
         --and y.SEMANA = v_semana
         and y.FEC_DESDE = v_fec_desde;
         --and y.FEC_HASTA = v_fec_hasta;
      if v_for_ree_cur_forward = 'S' then
        delete from ge_par_dinamicos a
         where a.parametro = 'FOR_REE_CUR_FORWARD';
      end if;
   end if;

   insert into LC_FOR_CUR_FORWARD
   (cod_moneda, ano, semana, fec_desde, fec_hasta, dia_plazo, val_cotizacion)
   select k.cod_moneda, k.ano, k.semana, k.fec_desde, k.fec_hasta, k.dia_plazo, k.val_cotizacion
     from LC_FOR_CUR_FORWARD_TMP k;

   commit;
exception
  when others then
        RAISE_APPLICATION_ERROR(-20000,'Error en prl_car_dat_cur_forward - '||v_lugar||' -'||SQLERRM);
end;
/

