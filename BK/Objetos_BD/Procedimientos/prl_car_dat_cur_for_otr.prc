create or replace procedure it.PRL_CAR_DAT_CUR_FOR_OTR(P_COD_MONEDA IN VARCHAR2) is
  
  --//--Creado por rpavon--12/10/2017--//
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  --//--Para cargar datos de Curva de Forward desde--//
  --//--Publicacion en la pagna web de BCP--
  
  --Variables--
  v_lugar        varchar2(500);
  v_cod_moneda   LC_FOR_CUR_FORWARD.cod_moneda%type;
  v_cod_mon_archi  LC_FOR_CUR_FORWARD.cod_moneda%type;
  v_fec_subasta  date;
  v_can_control  number(6);
  v_for_ree_cur_forward ge_par_dinamicos.val_parametro%type;
begin
  v_lugar := 'Carga de Variables';
  v_cod_moneda := P_COD_MONEDA;
  
  v_lugar := 'Extraer fec subasta';
  SELECT TO_DATE(SUBSTR(UPPER(X.CAD_PLAZO),INSTR(UPPER(X.CAD_PLAZO),'SUBASTA DEL ')+12,((LENGTH(UPPER(X.CAD_PLAZO))+1) - (INSTR(UPPER(X.CAD_PLAZO),'SUBASTA DEL ')+12))),'DD/MM/YYYY'),
         SUBSTR(UPPER(X.CAD_PLAZO),INSTR(UPPER(X.CAD_PLAZO),'PYG/')+4,INSTR(UPPER(X.CAD_PLAZO),'SUBASTA')-22 )
    INTO V_FEC_SUBASTA, V_COD_MON_ARCHI
    FROM LC_FOR_CUR_FORWARD_TMP X
   WHERE UPPER(UPPER(X.CAD_PLAZO)) LIKE '%CURVA FORWARD%- SUBASTA DEL%';
  
  --Control de MOneda--
  if v_cod_mon_archi <> v_cod_moneda then
     RAISE_APPLICATION_ERROR(-20000,'Error. '||
                               'Moneda del Archivo :'||v_cod_mon_archi||' <> Moneda de Proceso:'||v_cod_moneda||
                               '. Verificar.');
  end if;
  
  v_lugar := 'Actualizar registros';     
  update LC_FOR_CUR_FORWARD_TMP x
     set x.cod_moneda = v_cod_moneda,
         --x.ano = to_number(to_char(v_fec_subasta,'yyyy')),
         --x.semana = to_number(to_char(v_fec_subasta,'ww')),
         x.fec_desde = v_fec_subasta,
         --x.fec_hasta = v_fec_subasta,
         x.dia_plazo = to_number(x.cad_plazo),
         x.val_cotizacion = to_number(x.cad_cotizacion)
   where UPPER(UPPER(X.CAD_PLAZO)) NOT LIKE '%CURVA FORWARD%- SUBASTA DEL%'
     and UPPER(UPPER(X.CAD_PLAZO)) NOT LIKE '%PLAZO%';
    
  v_lugar := 'Eliminar texto de cabecera - 2l';
  delete from LC_FOR_CUR_FORWARD_TMP x
   where UPPER(UPPER(X.CAD_PLAZO)) LIKE '%CURVA FORWARD%- SUBASTA DEL%'
      or UPPER(UPPER(X.CAD_PLAZO)) LIKE '%PLAZO%';
  
  v_lugar := 'Validar';
  v_can_control := 0;
  select nvl(count(*),0)
    into v_can_control
    from LC_FOR_CUR_FORWARD y
   where y.COD_MONEDA = v_cod_moneda 
     and y.fec_desde = v_fec_subasta;
   v_for_ree_cur_forward := nvl(fug_obt_pardinamico('FOR_REE_CUR_FORWARD'),'N');
   if ((nvl(v_can_control,0) > 0) and (v_for_ree_cur_forward = 'N')) then
        RAISE_APPLICATION_ERROR(-20000,'Error. '||
                               'Existen '||to_char(nvl(v_can_control,0))||' reg. de '||
                               'Mon:'||v_cod_moneda||'-Fec.Subasta:'||to_char(v_fec_subasta,'dd/mm/yyyy')||
                               '-P/ recargar definir par.dinamico FOR_REE_CUR_FORWARD en S');
   end if; 
   
   v_lugar := 'Insertar de temporal a produccion';
   if nvl(v_can_control,0) > 0 then
      delete from LC_FOR_CUR_FORWARD x
      where x.cod_moneda = v_cod_moneda
        and x.fec_desde = v_fec_subasta;
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
        RAISE_APPLICATION_ERROR(-20000,'Error en prl_car_dat_cur_for_otr - '||v_lugar||' -'||SQLERRM);
end;
/

