create or replace procedure it.PRA_TAR_DEB_ACT_MASIVO(P_TIP_PROCESO in varchar2
                                                  ,P_NRO_LOTE IN NUMBER
                                                  ,P_MSJ_PROCESO out varchar2) is
v_result varchar2(4000);
V_MENSAJE VARCHAR2(4000);
v_accion varchar2(500);
v_habilitado varchar2(1);
pragma autonomous_transaction;
begin
  if P_TIP_PROCESO = 'T' THEN
    v_accion := 'Activación';
  ELSE
    v_accion := 'Inactivación';
  END IF;
   begin
      v_habilitado := FUG_OBT_PARDINAMICO('BAN_PIN_ACT_HABILITADO');
      IF v_habilitado = 'S' AND P_TIP_PROCESO = 'T' THEN
         V_MENSAJE:= FUA_WSI_ACT_PIN_MASIVO(P_NRO_LOTE);
      ELSE
         V_MENSAJE := FUA_WSI_ACT_MASIVO(P_NRO_LOTE);                   
      END IF;
      
      commit;
	 exception
		    when others then
		    V_MENSAJE := 'Error al procesar la '||v_accion||' masiva: '||sqlerrm;	
        rollback;
	 end;
     P_MSJ_PROCESO := V_MENSAJE;
end PRA_TAR_DEB_ACT_MASIVO;
/

