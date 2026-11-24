CREATE OR REPLACE PROCEDURE IT.prg_ted_reg_mov_servicio(p_cod_lote cj_reg_mov_servicios.cod_lote%type, --varchar2(20)
                                                p_cod_documento cj_reg_mov_servicios.cod_documento%type, --varchar2(20)
                                                p_nro_atm cj_reg_mov_servicios.atm_id%type, --varchar2(10)
                                                p_nro_transaccion cj_reg_mov_servicios.nro_transaccion%type, --varchar2(20)
                                                p_servicio cj_reg_mov_servicios.servicio%type,-- varchar2(35)
                                                p_descripcion cj_reg_mov_servicios.des_transaccion%type, --varchar2(100)
                                                p_nom_persona cj_reg_mov_servicios.nom_completo%type, --varchar2(120)
                                                p_nro_documento cj_reg_mov_servicios.nro_documento%type, --varchar2(20)
                                                p_nro_tel cj_reg_mov_servicios.nro_telefono%type, --varchar2(15)
                                                p_cod_referencia cj_reg_mov_servicios.cod_referencia%type,--varchar2(20)
                                                p_cod_referencia2 cj_reg_mov_servicios.cod_referencia_2%type,--varchar2(20)
                                                p_cod_referencia3 cj_reg_mov_servicios.cod_referencia_3%type,--varchar2(20)
                                                p_monto cj_reg_mov_servicios.monto%type,--number(18,2)
                                                p_monto_operacion cj_reg_mov_servicios.monto_operacion%type,--number(18,2)
                                                p_estado cj_reg_mov_servicios.estado%type, --varchar2(1)
                                                p_cod_respuesta out number,
                                                p_msj_respuesta out varchar2) IS

  v_cod_error number :=0;
  v_msj_error varchar2(200);

BEGIN
  begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;

 --Validar los campos de entrada
  if p_cod_documento is null then
    v_cod_error := 1;
    v_msj_error := 'Código de documento no puede ser nulo';
  end if;
 if p_nro_atm is null then
    v_cod_error := 2;
    v_msj_error := 'Número de ATM no puede ser nulo';
  end if;
   if p_nro_transaccion is null then
    v_cod_error := 3;
    v_msj_error := 'Nro. de transacción no puede ser nulo';
  end if;
   if p_cod_lote is null then
    v_cod_error := 4;
    v_msj_error := 'Número de lote no puede ser nulo';
  end if;
  if p_estado not in ('P','E','T')  then
    v_cod_error := 5;
    v_msj_error := 'Estado solo puede ser los valores P,E ó T';
  end if;

    --Se realiza el insert a la tabla cj_reg_mov_servicios
    BEGIN
      insert into it.cj_reg_mov_servicios
                      (cod_lote, cod_documento, nro_transaccion, des_transaccion, atm_id, servicio, nom_completo, nro_documento, nro_telefono, cod_referencia, cod_referencia_2, cod_referencia_3, monto, monto_operacion, estado, fecha)
                    values
                      (p_cod_lote, p_cod_documento, p_nro_transaccion, p_descripcion, p_nro_atm, p_servicio, p_nom_persona, p_nro_documento, p_nro_tel, p_cod_referencia, p_cod_referencia2, p_cod_referencia3, p_monto, p_monto_operacion, p_estado, sysdate);


    EXCEPTION
      WHEN OTHERS THEN
       v_cod_error := 6;
       v_msj_error := 'No se ha podido realizar el insert.SqlErr:'||substr(sqlerrm, 70);
    END;

  if nvl(v_cod_error, 0) != 0 then
    p_cod_respuesta := v_cod_error;
    p_msj_respuesta := v_msj_error;
  else
    p_cod_respuesta := 0;
    p_msj_respuesta := 'OK';
  end if;

EXCEPTION
  when others then
    NULL;
END;
/

