create or replace procedure it.prg_mig_per_juridicas_librador is

   cursor per is
      select cod_persona, raz_social, nom_comercial, naturaleza, fec_apertura, cod_ramo,
             gar_tercero, cap_operativo, cod_area, rownum reg
        from it.mi_ba_per_juridicas_librador
        where cod_persona not in (select cod_persona from ba_per_juridicas);

   v_error varchar2(100);
   v_err   varchar2(100);
   v_ermsj varchar2(500);
   v_fecha date;
   v_fec date := pag_cal.fu_obt_fec_actual(1);

begin
   delete mi_logs where proceso = 'PER_JURIDICAS_LIBRADOR';

   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1;end;
   --Desabilitar los triggers
   sql_util.ejecute_dml('alter table ba_per_juridicas disable all triggers', v_err);
   sql_util.ejecute_dml('alter table ba_personas disable all triggers', v_err);
   --Habilitar los triggers
   sql_util.ejecute_dml('alter trigger ta_ba_per_juridicas enable', v_err);

   if v_err is not null then
      raise_application_error(-20000,'Al desabilitar triggers '||v_err);
   end if;


   for i in per loop
      begin
         insert into ba_per_juridicas(cod_persona, raz_social,nom_comercial, naturaleza,
                                      fec_apertura, cod_ramo, gar_tercero, cap_operativo, cod_area,
                                      usu_insercion,usu_modificacion, fec_insercion, fec_modificacion)
         values(i.cod_persona, i.raz_social, SUBSTR(i.nom_comercial,1,65), i.naturaleza,
                i.fec_apertura, i.cod_ramo, i.gar_tercero, i.cap_operativo, i.cod_area,
                'MIGRA','MIGRA',v_fec,v_fec);
      exception
         when others then
            v_error := sqlcode;
            v_ermsj := sqlerrm;
            v_fecha := sysdate;
            insert into mi_logs(nro_reg,nro_error,men_error,comentario,proceso,fec_proceso)
            values(i.reg,v_error,v_ermsj,i.cod_persona||' '||i.raz_social,'PER_JURIDICAS_LIBRADOR',v_fecha);
      end;
   end loop;
   --Habilitar los triggers

   sql_util.ejecute_dml('alter table ba_per_juridicas enable all triggers', v_err);
   sql_util.ejecute_dml('alter table ba_personas enable all triggers', v_err);
   if v_err is not null then
      raise_application_error(-20000,'Al habilitar triggers '||v_err);
   end if;

exception
   when others then
      v_error := sqlcode;
      v_ermsj := nvl(v_err, sqlerrm);
      v_fecha := sysdate;
      insert into mi_logs(nro_reg,nro_error,men_error,comentario,proceso,fec_proceso)
      values(1,v_error,v_ermsj,'verif_juridicas','PER_JURIDICAS_LIBRADOR',v_fecha);
      commit;
end;
/
