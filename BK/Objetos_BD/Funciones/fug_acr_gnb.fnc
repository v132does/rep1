CREATE OR REPLACE FUNCTION IT.fug_acr_gnb(
 p_nro_referencia  IN ge_movimientos.nro_documento%TYPE,
 p_fecha           IN date,
 p_cta_operativa   IN varchar2 ,
 p_nro_ref_bcp     IN VARCHAR2 DEFAULT NULL
)
return varchar2
IS
v_nro_cta varchar2(30);
v_importe number(18,4);
v_error   varchar2(10);
v_nro_ref_gnb varchar2(30);
v_nom_respuesta varchar2(30);
v_cta_operativa  varchar2(30);
v_resultado varchar2(3000);
v_cta_gnb varchar2(10);
v_des_respuesta varchar2(3000);
v_retorno         typ_mensajeRespuesta := typ_mensajeRespuesta();

BEGIN
  
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;

  v_cta_gnb :='N';
  v_error := null;
  v_nom_respuesta := null;
  v_des_respuesta := null;
  v_importe:=0;
  v_resultado:= null;


  begin
    select 'S', k.nro_ref_bt, k.imp_cre
       into v_cta_gnb,v_nro_ref_gnb,v_importe
         from GE_VAL_CTA_GNB k
             where k.nro_referencia= p_nro_referencia
                  AND k.fecha=p_fecha;
   exception
      when no_data_found then
         v_cta_gnb:='N';
      when too_many_rows then
         v_cta_gnb:='N';
      when others then
         v_cta_gnb:='N';
   end;
   --Solo validamos si es cuenta GNB
   if nvl(v_cta_gnb,'N') = 'S' then
        v_retorno:= paw_bts.fu_snp_envio(v_nro_ref_gnb, p_cta_operativa,v_importe, p_nro_ref_bcp); 
        v_error  := v_retorno.error;
        v_nom_respuesta:= v_retorno.nombreRespuesta ;
        v_des_respuesta:= v_retorno.descripcionRespuesta;
        if upper(v_error) <> 'N' and upper(v_des_respuesta) <> 'OP_APROBADA' THEN
            v_resultado:= 'ERROR: '||v_des_respuesta;
        else
            v_resultado:='OP_APROBADA';
        end if;
    else
       v_resultado:='OP_APROBADA';
    end if;

   return v_resultado;

EXCEPTION
  when others then
     v_resultado:= 'ERROR: ';
     return v_resultado;
END;
/

