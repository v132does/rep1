create or replace procedure it.PRG_OBT_OBJ_BLOQUEADOS is
   V_NRO_SECUENCIA number(20) := S_NRO_SEC_BLOQ.NEXTVAL;
begin
   /*insert into BA_LOG_BLOQUEOS
      select V_NRO_SECUENCIA
            ,FECHA
            ,FEC_PROCESO
            ,PREV_EXEC_START
            ,LAST_ACTIVE_TIME
            ,TIE_EJECUCION
            ,SID
            ,object
            ,USERNAME
            ,PROGRAM
            ,LOCK_TYPE
            ,MODE_HELD
            ,MODE_REQUESTED
            ,SQL_TEXT
            ,SQL_FULLTEXT
            ,ACTION
            ,USU_INSERCION
        from GV_OBJ_BLOQUEADOS;
   commit;
exception
   when others then
      RAISE_APPLICATION_ERROR(-2000, 'Error al listar objetos bloqueados: ' || sqlerrm);*/
      null;
end;
/

