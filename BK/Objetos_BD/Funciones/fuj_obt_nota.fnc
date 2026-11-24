CREATE OR REPLACE FUNCTION IT.FUJ_OBT_NOTA
 (P_NRO_CUENTA IN VARCHAR2, P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_msj varchar2(500) := '';
v_fila varchar2(200);
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
begin
  Select '!'||descripcion, rowid
    into v_msj, v_fila
    from cr_per_notas b
   where cod_persona = p_cod_persona
     and estado = 'P'; --- Solo notas pendientes
     -- actualizo el mensaje como enviado
   update cr_per_notas
      set estado = 'R'
    where rowid = v_fila;  
  commit;   
  return v_msj;
Exception
  When NO_DATA_FOUND Then
    begin
      Select '!'||descripcion, rowid
        into v_msj, v_fila
        from cr_per_notas b
       where cod_persona =  (select cod_persona from ge_cta_clientes where nro_cuenta = p_nro_cuenta and relacion = 'P')
         and estado = 'P'
         and rownum = 1; --- Solo notas pendientes
     -- actualizo el mensaje como enviado
     update cr_per_notas
        set estado = 'R'
      where rowid = v_fila; 
     commit;         
      return v_msj;
    Exception
      When NO_DATA_FOUND Then
         return '';
      When TOO_MANY_ROWS Then
         return v_msj;
    end;
  When TOO_MANY_ROWS Then
     return v_msj;
end;
/

