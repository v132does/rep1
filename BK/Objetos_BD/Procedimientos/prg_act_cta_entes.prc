create or replace procedure it.PRG_ACT_CTA_ENTES(p_nro_cuenta varchar2,
p_cod_ente number,
p_fec_ult_acreditacion ge_cta_entes.fec_ult_acreditacion%type,
p_val_parametro varchar2)
IS
--PROCEDIMIENTO QUE ACTUALIZA EL ESTADO DE CUENTA DE SALARIO
   v_nro_cuenta     ge_cta_entes.nro_cuenta%type;
   v_cod_ente       ge_cta_entes.cod_ente%type;
   v_fec_ult_acreditacion  ge_cta_entes.fec_ult_acreditacion%type;
   v_val_parametro    ge_cta_dat_adicionales.val_parametro%type;
   v_programa       ge_log_errores.cod_programa%type :='PRA_CTA_INACTIVA';
   v_errores        ge_log_errores.det_error%type;
   v_can_registros  ge_cta_entes.cod_ente%type;

begin
   v_errores :='Inicio del proceso';
   v_cod_ente := p_cod_ente;
   v_nro_cuenta := p_nro_cuenta;
   v_fec_ult_acreditacion := p_fec_ult_acreditacion;
   v_val_parametro := p_val_parametro;
   v_can_registros :=0;
  --VERIFICAMOS SI EXISTE EN LA TABLA GE_CTA_ENTES CON EL CODIGO DE ENTE Y NUMERO DE CUENTA DE ACREDITACIÓN
   begin
        select count(*) into v_can_registros
        from ge_cta_entes p
        where p.nro_cuenta=v_nro_cuenta
        and p.cod_ente=v_cod_ente;
   exception
        when others then
        v_can_registros := 0;
   end;
       --ACTUALIZAMOS EL CAMPO ULTIMA FECHA ACREDITACION Y ESTADO DE LA TABLA GE_CTA_ENTES
        if v_can_registros > 0 then
           update ge_cta_entes set FEC_ULT_ACREDITACION=v_fec_ult_acreditacion,CTA_ENT_ESTADO=v_val_parametro
           where nro_cuenta=v_nro_cuenta
           and cod_ente=v_cod_ente;
           --ACTUALIZAMOS EL VALOR ADICIONAL POR CUENTA
           update ge_cta_dat_adicionales set val_parametro=v_val_parametro
           where nro_cuenta=v_nro_cuenta
           and parametro='PAG_CTA_AHO_EST';
           --ACTUALIZAMOS EL VALOR DEL PARAMETRO ADICIONAL POR ENTE
           update ge_par_entes set val_parametro=v_val_parametro
           where cod_ente=v_cod_ente
           and parametro='PAG_ENT_EST';
       end if;
exception
      when others then
      v_errores := substr(sqlerrm,4000);
      PRG_INS_LOG_PROGRAMAS(v_programa,'Error en el cierre:' || v_errores,null,v_nro_cuenta ||'-'|| v_cod_ente);
end;
/

