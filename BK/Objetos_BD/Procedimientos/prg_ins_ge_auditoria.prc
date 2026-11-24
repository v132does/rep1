CREATE OR REPLACE PROCEDURE IT.PRG_INS_GE_AUDITORIA
 (RP_GAUDI IN GE_AUDITORIAS%ROWTYPE
 )
 IS
 v_fec_sistema date;
 v_tabla ge_auditorias.tabla%type;
 
 cursor c_log_tablas is
        select x.val_minimo tabla
          from ba_cod_referencias x
         where x.dominio = 'GE_TAB_REG_LOGS'
           and x.val_minimo = v_tabla;
BEGIN
   if rp_gaudi.detalle is not null then
      v_fec_sistema := sysdate;
      v_tabla := rp_gaudi.tabla;
      IF rp_gaudi.tip_novedad IN ('E','M') then
          insert into ge_auditorias
          (tabla, clave, usuario,
           fec_sistema,  fec_calendario,
           tip_novedad,  origen,
           terminal, detalle)
          values
          (v_tabla, rp_gaudi.clave, USER,
           v_fec_sistema, rp_gaudi.fec_calendario, rp_gaudi.tip_novedad,
           PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_gaudi.detalle);
      end if;
      --Agregado para Insertar tabla de LOG--      
      for tab in c_log_tablas loop
          insert into ge_log_tablas
          (tabla, clave, usuario,
           fec_sistema,  fec_calendario,
           tip_novedad,  origen,
           terminal, detalle)
          values
          (tab.tabla, rp_gaudi.clave, USER,
           v_fec_sistema, rp_gaudi.fec_calendario, rp_gaudi.tip_novedad,
           PAE_CNF.G_PROGRAMA, PAE_CNF.FU_OBT_TERMINAL, rp_gaudi.detalle);
      end loop;       
   end if;
END;
/

