CREATE OR REPLACE PROCEDURE IT.prg_ins_per_atm_noclientes(p_nro_documento  ba_per_atm_no_clientes.nro_documento%type,
                                                p_tip_documento   ba_per_atm_no_clientes.cod_tip_documento%type,
                                                p_nom_completo   ba_per_atm_no_clientes.nom_ape%type,
                                                p_telefono       ba_per_atm_no_clientes.telefono%type,
                                                p_direccion     ba_per_atm_no_clientes.direccion%type,
                                                p_email      ba_per_atm_no_clientes.email%type,
                                                p_nro_transaccion    BA_ATM_TRAN_DEP_NOCLIE.NRO_TRANSACCION%type ,
                                                p_atm               BA_ATM_TRAN_DEP_NOCLIE.ATM_NOM%type,
                                                p_tip_dep           BA_ATM_TRAN_DEP_NOCLIE.TIP_DEPOSITO%type,
                                                p_cod_respuesta out number,
                                                p_msj_respuesta out varchar2) IS
  v_cod_error number;
  v_msj_error varchar2(200);
  v_existe number;
BEGIN
  v_cod_error :=0;
 --Validar los campos de entrada
  if p_nro_documento is null then
    v_cod_error := 1;
    v_msj_error := 'Nro. de documento no puede ser nulo';
  end if;
 if p_tip_documento is null then
    v_cod_error := 2;
    v_msj_error := 'Tipo de documento no puede ser nulo';
  end if;
  if p_atm is null then
    v_cod_error := 7;
    v_msj_error := 'Nro de ATM no puede ser nulo';
  end if;
  if p_tip_dep is null then
    v_cod_error := 8;
    v_msj_error := 'Tip deposito no puede ser nulo';
  end if;

  --Se valida que si ya existe ese número de documento.
  begin
    select count(K.NRO_DOCUMENTO)
      into v_existe
      from BA_PER_ATM_NO_CLIENTES K
     where k.nro_documento = p_nro_documento;
   exception
     when others then
       v_existe := 0;
    end;
 if nvl(v_cod_error, 0) = 0 then
  if v_existe = 0 then
   BEGIN
       --Insert de datos de no clientes
      insert into it.BA_PER_ATM_NO_CLIENTES
        (NRO_DOCUMENTO,COD_TIP_DOCUMENTO,NOM_APE,DIRECCION,TELEFONO,EMAIL,FEC_ACTUALIZACION)
      values
        (p_nro_documento, p_tip_documento,p_nom_completo,p_direccion,p_telefono,p_email,sysdate);
       --Insert de datos de la transacción
       insert into it.ba_atm_tran_dep_noclie
        (NRO_DOCUMENTO,NRO_TRANSACCION,ATM_NOM,FEC_TRANSACCION,TIP_DEPOSITO)
      values
        (p_nro_documento,p_nro_transaccion,p_atm,sysdate,p_tip_dep);
    EXCEPTION
       when others then
          v_cod_error := 9;
          v_msj_error := 'Error al realizar el insert. ' || substr(sqlerrm, 180);
    END;
  else
    BEGIN
     update it.BA_PER_ATM_NO_CLIENTES a
        set a.nom_ape   = p_nom_completo,
            a.direccion = p_direccion,
            a.telefono  = p_telefono,
            a.email      = p_email,
            a.fec_actualizacion = sysdate
      where a.nro_documento = p_nro_documento;
      EXCEPTION
         when others then
          v_cod_error := 10;
          v_msj_error := 'Error al realizar el update. ' || substr(sqlerrm, 180);
        END;
     IF v_cod_error = 0 THEN
      BEGIN
      --Insert de datos de la transacción de depósito
       insert into it.ba_atm_tran_dep_noclie
        (NRO_DOCUMENTO,NRO_TRANSACCION,ATM_NOM,FEC_TRANSACCION,TIP_DEPOSITO)
       values
        (p_nro_documento,p_nro_transaccion,p_atm,sysdate,p_tip_dep);
      EXCEPTION
         when others then
          v_cod_error := 11;
          v_msj_error := 'Error al realizar el insert. ' || substr(sqlerrm, 180);
      END;
     END IF;
  end if;
end if;
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

