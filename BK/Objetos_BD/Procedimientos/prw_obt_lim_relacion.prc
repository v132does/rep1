CREATE OR REPLACE PROCEDURE IT.prw_obt_lim_relacion(p_tip_operacion IN VARCHAR2,
                                                 p_cod_tip_mensaje OUT bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                                 p_cod_tra_padre   OUT ge_transacciones.cod_transaccion%TYPE,
                                                 p_req_monto       OUT bw_cod_lim_relacion.req_monto%TYPE,
                                                 p_tip_ente        OUT ge_entes.tipo%TYPE) is
BEGIN
  select p.cod_tip_mensaje, p.cod_tra_padre, p.req_monto, p.tip_ente
    into p_cod_tip_mensaje, p_cod_tra_padre, p_req_monto, p_tip_ente
    from bw_cod_lim_relacion p
   where p.nombre = nvl(trim(p_tip_operacion), 'x');
EXCEPTION
  WHEN OTHERS THEN
    p_cod_tip_mensaje := NULL;
    p_cod_tra_padre   := NULL;
    p_req_monto       := NULL;
END;
/

