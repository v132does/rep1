CREATE OR REPLACE PROCEDURE IT.prs_ver_snp_cierre IS
  v_estado           GE_SNP_HORARIOS.ESTADO%TYPE;
  v_fec_modificacion DATE;
  v_descripcion      ba_cod_referencias.significado%Type;
BEGIN

  v_descripcion := FUE_OBT_DES_REFCODES('PRS_SNP_CTL_CIERRE', 1, 'S');

  begin
    SELECT ESTADO, trunc(fec_modificacion)
      INTO v_estado, v_fec_modificacion
      FROM GE_SNP_HORARIOS
     WHERE DESCRIPCION = v_descripcion;
  exception
    when no_data_found then
      raise_application_error(-20000,
                              'Periodo ' || v_descripcion ||
                              ' no encontrado');
  end;

  IF v_estado = 'A' or
     (v_estado = 'C' and v_fec_modificacion != trunc(sysdate)) THEN
    raise_application_error(-20000,
                            'Periodo de ' || v_descripcion ||
                            ' aun no ha sido procesado y cerrado');
  END IF;

  v_descripcion := FUE_OBT_DES_REFCODES('PRS_SNP_CTL_CIERRE', 2, 'S');

  begin
    SELECT ESTADO, trunc(fec_modificacion)
      INTO v_estado, v_fec_modificacion
      FROM GE_SNP_HORARIOS
     WHERE DESCRIPCION = v_descripcion;
  exception
    when no_data_found then
      raise_application_error(-20000,
                              'Periodo ' || v_descripcion ||
                              ' no encontrado');
  end;

  IF v_estado = 'A' or
     (v_estado = 'C' and v_fec_modificacion != trunc(sysdate)) THEN
    raise_application_error(-20000,
                            'Periodo de ' || v_descripcion ||
                            ' aun no ha sido procesado y cerrado');
  END IF;

exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,
                            'Error en el proceso de verificación de estado de los periodos SNP');
    End if;
END;
/

