-- MDD-124 / FIELDESK-159387
-- Actualiza comentario de IT.SB_SNP_FLI.SITUACION
-- Incorpora estado N = Cancelado (garantía FLI reasignada / no vigente).
--
-- Ejecutar como IT (o usuario con privilegio COMMENT ON IT.SB_SNP_FLI).
-- Idempotente: COMMENT ON COLUMN reemplaza el texto anterior.

COMMENT ON COLUMN IT.sb_snp_fli.situacion IS
  'Situación del Mensaje. V-Enviado al BCP, P-Pendiente de Envío al BCP, R-Recibido, L-Operacion Liquidada, N-Cancelado.';
