CREATE OR REPLACE PROCEDURE IT.prg_ins_his_doc_catastrados(
    p_oper IN VARCHAR2, -- M=Modificacion, E=Eliminación
    p_cod_catastro IN ge_doc_catastros.cod_doc_catastro%TYPE
) IS
    c_modifica              CONSTANT VARCHAR2(1) := 'M';
    c_elimina               CONSTANT VARCHAR2(1) := 'E';
    v_lugar                 VARCHAR2(100);
    v_cat                   ge_doc_catastros%ROWTYPE;
    v_mensaje               varchar2(100);
BEGIN
    v_lugar := 'INICIO';
    
    -- Verificar parámetros
    IF p_oper IS NULL THEN
        v_mensaje := 'PARÁMETRO de tipo de operación debe tener valor';
        RETURN;
    END IF;
    
    IF p_cod_catastro IS NULL THEN
        v_mensaje := 'PARÁMETRO de identificador de catastro debe tener valor';
        RETURN;
    END IF;
  
    IF p_oper NOT IN (c_modifica, c_elimina) THEN
        v_mensaje := 'El tipo de operación puede ser de <M>odificación o de <E>liminación';
        RETURN;
    END IF;
    
    -- Verifica si el documento a modificar o eliminar está registrado.
    BEGIN
        v_lugar := 'VER GE_DOC_CATASTROS';
        SELECT *
            INTO v_cat
            FROM ge_doc_catastros
            WHERE cod_doc_catastro = p_cod_catastro;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF p_oper = c_modifica THEN       
                v_mensaje := 'modificar';
            ELSE
                v_mensaje := 'eliminar';
            END IF;
            v_mensaje := 'Documento a '||v_mensaje||' no existe como documento catastrado';
            RETURN;
    END;
    
    -- Inserta en la tabla histórica.
    BEGIN
      v_lugar := 'INSERTAR GE_DOC_CATASTROS_HIS';
      INSERT INTO ge_doc_catastros_his
                 (cod_doc_catastro, cod_persona, nro_cuenta, cod_tip_documento, 
                  nro_documento, fec_vto_documento, observacion, estado, usu_insercion, 
                  fec_insercion, usu_modificacion, fec_modificacion, usu_ins_historico, fec_ins_historico)
        select c.cod_doc_catastro, c.cod_persona, c.nro_cuenta, c.cod_tip_documento,
               c.nro_documento, c.fec_vto_documento, c.observacion, c.estado, usu_insercion,
               fec_insercion, usu_modificacion, fec_modificacion, user, sysdate
          FROM ge_doc_catastros c
         WHERE c.cod_doc_catastro = p_cod_catastro;
    
     EXCEPTION
        when no_data_found then
           null;
        when others then 
          null;
    END;
EXCEPTION
    WHEN OTHERS THEN
        raise_application_error(-20002, 'Error: PRG_INS_HIS_DOC_CATASTRADOS- '||v_lugar||': '||v_mensaje||'-'||SQLERRM);
END prg_ins_his_doc_catastrados;
/

