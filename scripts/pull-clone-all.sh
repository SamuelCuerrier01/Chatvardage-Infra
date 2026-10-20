#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
BASE_DIR="$(dirname "$INFRA_DIR")"
GITHUB_ORG="Chatvardage"
REPOS=(
   "A26_5A6_01-Infra"
   "A26_5A6_01-Frontend"
   "A26_5A6_01-Room-Service"
   "A26_5A6_01-Message-Service"
   "A26_5A6_01-Serveur-API"
   "A26_5A6_01-Authentification"
   "A26_5A6_01-User-Config-Service"
   "A26_5A6_01-Dashboard"
   "A26_5A6_01-Mobile"
)
SUCCESS=0
FAILED=0
CLONED=0
UPDATED=0
echo ""
echo "=================================================="
echo "       SYNCHRONISATION DES REPOS CHATVARDAGE"
echo "=================================================="
echo ""
echo "📁 Dossier : $BASE_DIR"
echo ""
echo "🔐 Vérification de la connexion GitHub SSH..."
if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
   echo ""
   echo "⚠️  Impossible de confirmer l'authentification SSH GitHub."
   echo "   Vérifie avec :"
   echo ""
   echo "   ssh -T git@github.com"
   echo ""
fi
echo ""
for repo in "${REPOS[@]}"; do
   REPO_PATH="$BASE_DIR/$repo"
   REPO_URL="git@github.com:$GITHUB_ORG/$repo.git"
   echo "--------------------------------------------------"
   echo "📦 $repo"
   echo "--------------------------------------------------"
   if [ ! -d "$REPO_PATH" ]; then
       echo "📥 Repo absent."
       echo "   Clonage depuis :"
       echo "   $REPO_URL"
       echo ""
       if git clone "$REPO_URL" "$REPO_PATH"; then
           echo ""
           echo "✅ $repo cloné avec succès."
           CLONED=$((CLONED + 1))
           SUCCESS=$((SUCCESS + 1))
       else
           echo ""
           echo "❌ Échec du clonage de $repo."
           FAILED=$((FAILED + 1))
       fi
       echo ""
       continue
   fi
   if [ ! -d "$REPO_PATH/.git" ]; then
       echo "❌ Le dossier existe mais n'est pas un dépôt Git :"
       echo "   $REPO_PATH"
       FAILED=$((FAILED + 1))
       echo ""
       continue
   fi
   CURRENT_REMOTE="$(git -C "$REPO_PATH" remote get-url origin 2>/dev/null || true)"
   if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
       echo "🔧 Correction de l'URL Git..."
       if git -C "$REPO_PATH" remote set-url origin "$REPO_URL"; then
           echo "✅ Origin configuré en SSH."
       else
           echo "❌ Impossible de modifier origin."
           FAILED=$((FAILED + 1))
           echo ""
           continue
       fi
   fi
   BRANCH="$(git -C "$REPO_PATH" branch --show-current)"
   if [ -z "$BRANCH" ]; then
       echo "❌ Impossible de déterminer la branche actuelle."
       FAILED=$((FAILED + 1))
       echo ""
       continue
   fi
   echo "🌿 Branche : $BRANCH"
   if [ -n "$(git -C "$REPO_PATH" status --porcelain)" ]; then
       echo "⚠️  Modifications locales détectées."
   else
       echo "✅ Aucun changement local."
   fi
   echo "⬇️  Pull..."
   if git -C "$REPO_PATH" pull --ff-only; then
       echo "✅ $repo est à jour."
       UPDATED=$((UPDATED + 1))
       SUCCESS=$((SUCCESS + 1))
   else
       echo "❌ Impossible de mettre à jour $repo."
       echo "   Vérifie les commits locaux ou les conflits."
       FAILED=$((FAILED + 1))
   fi
   echo ""
done
echo "=================================================="
echo "                     TERMINÉ"
echo "=================================================="
echo ""
echo "📥 Repos clonés : $CLONED"
echo "⬇️  Repos mis à jour : $UPDATED"
echo "✅ Succès : $SUCCESS"
echo "❌ Erreurs : $FAILED"
echo ""
echo "=================================================="
if [ "$FAILED" -gt 0 ]; then
   exit 1
else
   exit 0
fi