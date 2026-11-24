create or replace procedure it.prg_cancela_ctas as
  cursor a_cancelar is
    select t.nro_cuenta from GE_CUENTAS_TMP t where t.actualizado = 'N';
  v_hor_mov ge_movimientos.hora%type;

  /* Obtiene el siguiente segundo a partir de una hora dada. */
  FUNCTION LF_OBT_SIG_SEGUNDO(P_HORA IN GE_MOVIMIENTOS.HORA%TYPE)
    RETURN VARCHAR2 IS
    V_HORA    VARCHAR2(2);
    V_MINUTO  VARCHAR2(2);
    V_SEGUNDO VARCHAR2(2);
  BEGIN
    V_HORA    := SUBSTR(P_HORA, 1, 2);
    V_MINUTO  := SUBSTR(P_HORA, 4, 2);
    V_SEGUNDO := SUBSTR(P_HORA, 7, 2);
    IF P_HORA = P_HORA THEN
      V_SEGUNDO := TO_NUMBER(V_SEGUNDO) + 3;
      IF TO_NUMBER(V_SEGUNDO) > 59 THEN
        V_SEGUNDO := 0;
        V_MINUTO  := TO_NUMBER(V_MINUTO) + 1;
        IF TO_NUMBER(V_MINUTO) > 59 THEN
          V_MINUTO := 0;
          V_HORA   := TO_NUMBER(V_HORA) + 1;
          IF TO_NUMBER(V_HORA) > 23 THEN
            V_HORA := 0;
          END IF;
        END IF;
      END IF;
    END IF;
    -- espera dos segundo para q no se asigne el mismo seg en el sgte llamado
    --if fug_obt_tip_implementacion not in (1,3) then
    --   sys.dbms_lock.sleep(2);
    --end if;
    -- retorna el siguiente segundo a la hora dada ----------
    RETURN LPAD(V_HORA, 2, '0') || ':' || 
           LPAD(V_MINUTO, 2, '0') || ':' || 
           LPAD(V_SEGUNDO, 2, '0');
    ---------------------------------------------------------
  END;

begin
  v_hor_mov := to_char(sysdate, 'HH24:MI:SS');

  for b in a_cancelar loop
    v_hor_mov := LF_OBT_SIG_SEGUNDO(pag_gen.FU_OBT_SIG_SEGUNDO(v_hor_mov));
    --  dbms_output.put_line('Cta : ' || b.nro_cuenta   ||'  Mov :' || v_hor_Mov || ' - ' || ' sysdate ' || to_char(sysdate,'hh24:mi:ss') );                       
    pag_cta.PR_ACT_ESTADO(b.nro_cuenta,
                          'C',
                          sysdate,
                          v_hor_mov,
                          b.nro_cuenta,
                          'S');
    update ge_cuentas_tmp
       set actualizado = 'S'
     where nro_cuenta = b.nro_cuenta;
    commit;
  end loop;
  -- sys.dbms_lock.sleep(2);

end prg_cancela_ctas;
/

