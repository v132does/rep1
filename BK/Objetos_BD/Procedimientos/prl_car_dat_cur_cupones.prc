create or replace procedure it.PRL_CAR_DAT_CUR_CUPONES is
  
  --//--Creado por rpavon--12/10/2017--//
  --//--Proyecto: CNFNORMA-274-AJUSTES FORWARD--//
  --//--Para cargar datos de Curva de Cupones desde--//
  --//--Publicacion en la pagna web de BCP--
  
  --Variables--
  v_lugar        varchar2(500);
  v_cod_moneda   LC_FOR_CUR_CUPONES.cod_moneda%type;
  v_fec_subasta  date;
  v_can_control  number(6);
  v_for_ree_cur_cupon ge_par_dinamicos.val_parametro%type;
begin
  v_lugar := 'Carga de Variables';
  v_cod_moneda := pag_gen.FU_OBT_MON_FUERTE;
  
  v_lugar := 'Extraer fec subasta';
  SELECT TO_DATE(SUBSTR(UPPER(X.CAD_PLAZO),INSTR(UPPER(X.CAD_PLAZO),'SUBASTA DEL ')+12,((LENGTH(UPPER(X.CAD_PLAZO))+1) - (INSTR(UPPER(X.CAD_PLAZO),'SUBASTA DEL ')+12))),'DD/MM/YYYY')
    INTO V_FEC_SUBASTA
    FROM LC_FOR_CUR_CUPONES_TMP X
   WHERE UPPER(UPPER(X.CAD_PLAZO)) LIKE '%CURVA DE RENDIMIENTO CUP%N CERO - SUBASTA DEL%';
  
  v_lugar := 'Actualizar registros';
  update LC_FOR_CUR_CUPONES_TMP x
     set x.cod_moneda = v_cod_moneda,
         x.fec_subasta = v_fec_subasta,
         x.dia_plazo = to_number(x.cad_plazo),
         x.val_tasa = to_number(x.cad_tasa)
   where UPPER(UPPER(X.CAD_PLAZO)) NOT LIKE '%CURVA DE RENDIMIENTO CUP%N CERO - SUBASTA DEL%'
     and UPPER(UPPER(X.CAD_PLAZO)) NOT LIKE '%PLAZO%';
    
  v_lugar := 'Eliminar texto de cabecera - 2l';
  delete from LC_FOR_CUR_CUPONES_TMP x
   where UPPER(UPPER(X.CAD_PLAZO)) LIKE '%%CURVA DE RENDIMIENTO CUP%N CERO - SUBASTA DEL%%'
      or UPPER(UPPER(X.CAD_PLAZO)) LIKE '%PLAZO%';
  
  v_lugar := 'Validar';
  v_can_control := 0;
  select nvl(count(*),0)
    into v_can_control
    from LC_FOR_CUR_CUPONES y
   where y.COD_MONEDA = v_cod_moneda 
     and y.fec_subasta = v_fec_subasta;
   v_for_ree_cur_cupon := nvl(fug_obt_pardinamico('FOR_REE_CUR_CUPON'),'N');
   if ((nvl(v_can_control,0) > 0) and (v_for_ree_cur_cupon = 'N')) then
        RAISE_APPLICATION_ERROR(-20000,'Error. '||
                               'Existen '||to_char(nvl(v_can_control,0))||' reg. de '||
                               'Mon:'||v_cod_moneda||'-Fec.Subasta:'||to_char(v_fec_subasta,'dd/mm/yyyy')||
                               '-P/ recargar definir par.dinamico FOR_REE_CUR_CUPON en S');
   end if; 
   
   v_lugar := 'Insertar de temporal a produccion';
   if nvl(v_can_control,0) > 0 then
      delete from LC_FOR_CUR_CUPONES x
      where x.cod_moneda = v_cod_moneda
        and x.fec_subasta = v_fec_subasta;
      if v_for_ree_cur_cupon = 'S' then
        delete from ge_par_dinamicos a
         where a.parametro = 'FOR_REE_CUR_CUPON';
      end if;
   end if;
   
   insert into LC_FOR_CUR_CUPONES
   (COD_MONEDA, FEC_SUBASTA, DIA_PLAZO, VAL_TASA)
   select k.cod_moneda, k.fec_subasta, k.dia_plazo, k.val_tasa
     from LC_FOR_CUR_CUPONES_TMP k;

   commit;
exception
  when others then
        RAISE_APPLICATION_ERROR(-20000,'Error en prl_car_dat_cur_cupones - '||v_lugar||' -'||SQLERRM);
end;
/

