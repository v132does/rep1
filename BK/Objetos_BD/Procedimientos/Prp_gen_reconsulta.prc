CREATE OR REPLACE Procedure IT.Prp_Gen_reconsulta(p_cod_persona ba_personas.cod_persona%TYPE,
                                                  p_cod_error   OUT NUMBER,
                                                  p_msj_error   OUT VARCHAR2) Is
  --
  v_cod_error NUMBER;
  v_msj_error VARCHAR2(2000);
Begin
  v_cod_error := null;
  v_msj_error := null;
  Begin
    Pre_Ini_Aplicacion;
    Pae_Cnf.g_Cod_Modulo := 1;
  End;
BEGIN
    insert into ge_ing_clientes
      (cod_ing_cliente, cod_persona, observacion)
    values
      (IT.S_COD_ING_CLIENTE.NEXTVAL, p_cod_persona,p_cod_persona||': ha sido Re-scoreada.');
    commit;
  EXCEPTION
    When others then
       v_cod_error := 1;
       v_msj_error := 'No se puede insertar en ge_ing_clientes.'||substr(sqlerrm,50);
  END;

   IF nvl(v_cod_error, '000') = '000' THEN
    v_cod_error := 0;
    v_msj_error := 'Proceso concluido con exito.';
  END IF;
   p_cod_error := v_cod_error;
   p_msj_error := v_msj_error;
    Commit;
End;
/
